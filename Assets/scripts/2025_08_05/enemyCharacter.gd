extends BaseCharacter
class_name EnemyCharacter

@onready var detection_area: Area2D = $Body/DetectionArea
@onready var shape_detection: CollisionShape2D = $Body/DetectionArea/shape_detection
@onready var soft_collision_area: Area2D = $Areas/SoftCollisionArea
@onready var view_ray: RayCast2D = $RayCasts/ViewRay

@onready var between_states_timer: Timer = $Timers/BetweenStatesTimer
@onready var emergency_timer: Timer = $Timers/EmergencyTimer

var target_player: Node2D = null
var player_in_attack_range: bool = false
var player_in_detection_zone: bool = false
var chase_direction: int = 0
var can_see_player: bool = false
var has_jumped: bool = false

var air_time: float = 0.0
var has_used_double_jump: bool = false
var has_used_triple_jump: bool = false
var air_time_for_double_jump: float = 0.2

var dash_decision_cooldown: float = 0.0
var big_attack_decision_cooldown: float = 0.0

var stuck_time: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var position_check_timer: float = 0.0

func initialize_character() -> void:
	if not capabilities:
		capabilities = CharacterCapabilities.new()
		capabilities.can_walk = true
		capabilities.can_jump = true
		capabilities.can_attack = true
		capabilities.can_chase = true
		capabilities.can_patrol = true
		capabilities.has_detection_area = true
		capabilities.has_view_ray = true
	
	if shape_detection:
		shape_detection.disabled = true
	
	init_additional_timers()
	connect_additional_signals()
	
	if capabilities.can_patrol:
		var random_state = randf()
		if random_state < capabilities.initial_state_idle_chance:
			change_state(State.IDLE)
		else:
			change_state(State.WALKING)
			if randf() < 0.5:
				movement_direction = -1
			else:
				movement_direction = 1
	
	call_deferred("start_patrol_behavior")

func init_additional_timers() -> void:
	if between_states_timer:
		between_states_timer.one_shot = true
		between_states_timer.timeout.connect(_on_between_states_timer_timeout)
	
	if emergency_timer:
		emergency_timer.wait_time = 4.0
		emergency_timer.one_shot = true
		emergency_timer.timeout.connect(_on_emergency_timer_timeout)

func connect_additional_signals() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

func process_character(delta: float) -> void:
	update_direction()
	update_chase_direction()
	if target_player:
		update_view_ray(target_player)
	
	if dash_decision_cooldown > 0:
		dash_decision_cooldown -= delta
	if big_attack_decision_cooldown > 0:
		big_attack_decision_cooldown -= delta
	
	if not is_on_floor():
		air_time += delta
	else:
		air_time = 0.0
		has_used_double_jump = false
		has_used_triple_jump = false
	
	position_check_timer += delta
	if position_check_timer >= 0.5:
		position_check_timer = 0.0
		if abs(global_position.x - last_position.x) < 5 and current_state == State.CHASING:
			stuck_time += 0.5
		else:
			stuck_time = 0.0
		last_position = global_position

func physics_process_character(_delta: float) -> void:
	handle_soft_collisions()
	handle_ai_decisions()

func handle_movement(_delta: float) -> void:
	if current_state == State.DEATH or current_state == State.ATTACKING or current_state == State.KNOCKBACK:
		return
	
	if current_state == State.JUMPING:
		if is_on_floor() and has_jumped:
			has_jumped = false
			if player_in_detection_zone and can_see_player:
				change_state(State.CHASING)
			else:
				change_state(State.WALKING)
		return
	
	if player_in_attack_range and target_player and is_instance_valid(target_player):
		if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
			change_state(State.ATTACKING)
		return
	
	if player_in_detection_zone and target_player and is_instance_valid(target_player) and can_see_player:
		var y_difference = global_position.y - target_player.global_position.y
		
		if y_difference > 0 and y_difference < abs(character_data.jump_velocity) * 0.8 and is_on_floor() and chase_direction != 0:
			change_state(State.JUMPING)
		elif y_difference > abs(character_data.jump_velocity) * 0.8 or chase_direction == 0:
			change_state(State.IDLE)
		else:
			change_state(State.CHASING)
	elif player_in_detection_zone and not can_see_player:
		if current_state != State.IDLE and current_state != State.WALKING:
			if stuck_time > 1.0:
				change_state(State.IDLE)
			else:
				change_state(State.WALKING)
	else:
		if current_state == State.CHASING or current_state == State.IDLE:
			if between_states_timer and not between_states_timer.time_left > 0:
				start_patrol_behavior()

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if current_state == State.WALL_SLIDING:
			velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
		else:
			super.handle_gravity(delta)

func handle_actions() -> void:
	match current_state:
		State.IDLE:
			velocity.x = 0
		State.WALKING:
			if is_on_floor() and check_edge_or_wall():
				movement_direction *= -1
			velocity.x = movement_direction * character_data.speed
		State.JUMPING:
			if chase_direction != 0 and can_see_player:
				velocity.x = chase_direction * character_data.speed
			else:
				velocity.x = move_toward(velocity.x, 0, character_data.speed * 0.1)
			
			if not is_on_floor() and player_in_attack_range and capabilities.can_air_attack:
				if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
					change_state(State.ATTACKING)
		State.CHASING:
			if chase_direction != 0:
				if check_edge_or_wall_for_chase(chase_direction):
					velocity.x = 0
				else:
					velocity.x = chase_direction * character_data.speed
					movement_direction = chase_direction
			else:
				velocity.x = 0
		State.ATTACKING:
			velocity.x = 0
		State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			if chase_direction != 0 and can_see_player:
				velocity.x = chase_direction * character_data.speed
			else:
				velocity.x = move_toward(velocity.x, 0, character_data.speed * 0.1)
		State.WALL_SLIDING:
			pass
		State.WALL_JUMPING:
			if wall_jump_control_timer and wall_jump_control_timer.is_stopped():
				if chase_direction != 0:
					velocity.x = chase_direction * character_data.speed * 0.7

func handle_state_physics() -> void:
	if dash_timer and not dash_timer.is_stopped():
		change_state(State.DASHING)
		return
	
	check_floor_state()

func handle_ai_decisions() -> void:
	if current_state == State.DEATH or current_state == State.ATTACKING or current_state == State.KNOCKBACK:
		return
	
	if stuck_time > 1.0 and current_state == State.CHASING and not is_on_floor():
		if capabilities.can_double_jump and not has_used_double_jump and can_double_jump:
			perform_double_jump()
			has_used_double_jump = true
			stuck_time = 0.0
			return
	
	if stuck_time > 2.0 and current_state == State.CHASING:
		change_state(State.IDLE)
		stuck_time = 0.0
		return
	
	if not target_player or not is_instance_valid(target_player):
		return
	
	var player_pos = target_player.global_position
	var my_pos = global_position
	var x_distance = abs(player_pos.x - my_pos.x)
	var y_distance = player_pos.y - my_pos.y
	
	if can_see_player:
		if not is_on_floor() and air_time > air_time_for_double_jump:
			if capabilities.can_double_jump and not has_used_double_jump and can_double_jump:
				if y_distance < -50 and x_distance < 200:
					perform_double_jump()
					has_used_double_jump = true
					return
			
			if capabilities.can_triple_jump and has_used_double_jump and not has_used_triple_jump and can_triple_jump:
				if y_distance < -100 and x_distance < 150 and stamina_current >= character_data.triple_jump_stamina_cost:
					perform_triple_jump()
					has_used_triple_jump = true
					return
		
		if capabilities.can_dash and can_dash and dash_decision_cooldown <= 0:
			if is_on_floor() and x_distance > character_data.detection_range - 100:
				if stamina_current >= character_data.dash_stamina_cost:
					attempt_enemy_dash()
					dash_decision_cooldown = 2.0
					return
		
		if capabilities.can_big_attack and big_attack_decision_cooldown <= 0:
			if not is_on_floor() and y_distance > 50 and x_distance < 200:
				if stamina_current >= character_data.big_attack_stamina_cost:
					perform_big_attack()
					big_attack_decision_cooldown = 3.0
					return
	
	if capabilities.can_wall_jump and current_state == State.WALL_SLIDING:
		if y_distance < -50:
			var wall_direction = 1.0
			if left_wall_ray.is_colliding():
				wall_direction = 1.0
			elif right_wall_ray.is_colliding():
				wall_direction = -1.0
			
			velocity.y = character_data.jump_velocity * 0.3
			velocity.x = wall_direction * character_data.wall_jump_force * character_data.wall_jump_away_multiplier
			change_state(State.WALL_JUMPING)
			can_wall_jump = false
			return

func start_patrol_behavior() -> void:
	if not player_in_detection_zone and current_state != State.DEATH and current_state != State.ATTACKING and current_state != State.JUMPING:
		if character_data and between_states_timer:
			var random_time = randf_range(character_data.patrol_state_min_time, character_data.patrol_state_max_time)
			between_states_timer.wait_time = random_time
			between_states_timer.start()

func update_chase_direction() -> void:
	if player_in_detection_zone and target_player and is_instance_valid(target_player):
		var x_difference = target_player.global_position.x - global_position.x
		if abs(x_difference) < character_data.position_tolerance:
			chase_direction = 0
		else:
			chase_direction = sign(x_difference)
	else:
		chase_direction = 0

func check_edge_or_wall() -> bool:
	if movement_direction > 0:
		if right_wall_ray.is_colliding():
			return true
		if ground_check_ray.is_colliding() and not ground_check_ray_2.is_colliding():
			return true
	else:
		if left_wall_ray.is_colliding():
			return true
		if ground_check_ray.is_colliding() and not ground_check_ray_3.is_colliding():
			return true
	return false

func check_edge_or_wall_for_chase(direction: float) -> bool:
	if can_see_player:
		return false
		
	if direction > 0:
		if right_wall_ray.is_colliding():
			return true
		if ground_check_ray.is_colliding() and not ground_check_ray_2.is_colliding():
			return true
	else:
		if left_wall_ray.is_colliding():
			return true
		if ground_check_ray.is_colliding() and not ground_check_ray_3.is_colliding():
			return true
	return false

func update_direction() -> void:
	if current_state == State.DEATH:
		return

	if current_state == State.CHASING or current_state == State.ATTACKING or current_state == State.JUMPING:
		if chase_direction != 0:
			movement_direction = chase_direction

	body.scale.x = -movement_direction

func handle_soft_collisions() -> void:
	if not soft_collision_area:
		return
		
	if current_state == State.DEATH or current_state == State.ATTACKING:
		return
	
	var push_vector = Vector2.ZERO
	var overlapping_bodies = soft_collision_area.get_overlapping_bodies()
	
	for _body in overlapping_bodies:
		if _body == self:
			continue
		if not _body.is_in_group("Enemy"):
			continue
		
		var distance_vector = global_position - _body.global_position
		var distance = distance_vector.length()
		
		if distance < 1.0:
			distance = 1.0
		
		var push_strength = 100.0 / distance
		push_vector += distance_vector.normalized() * push_strength
	
	if push_vector.length() > 0:
		velocity += push_vector

func update_view_ray(b: Node2D) -> void:
	if player_in_detection_zone and view_ray:
		view_ray.target_position = to_local(b.global_position)
		
		if not view_ray.is_colliding():
			can_see_player = true
		else:
			can_see_player = false

func attempt_enemy_dash() -> void:
	if not can_dash or not capabilities.can_dash:
		return
	
	if stamina_current < character_data.dash_stamina_cost:
		return
	
	var dash_direction = chase_direction
	if dash_direction == 0:
		return
	
	perform_dash(dash_direction)

func perform_big_attack() -> void:
	stamina_current -= character_data.big_attack_stamina_cost
	stamina_regen_timer = character_data.stamina_regen_delay
	change_state(State.BIG_ATTACK)

func enter_state(state: State) -> void:
	super.enter_state(state)
	
	match state:
		State.IDLE:
			velocity.x = 0
			if not player_in_detection_zone:
				start_patrol_behavior()
		State.WALKING:
			if not player_in_detection_zone:
				start_patrol_behavior()
		State.JUMPING:
			if is_on_floor() and not has_jumped:
				velocity.y = character_data.jump_velocity * 0.8
				has_jumped = true
				jump_count = 1
				can_double_jump = true
		State.DOUBLE_JUMPING:
			jump_count = 2
			can_triple_jump = true
		State.TRIPLE_JUMPING:
			jump_count = 3
		State.CHASING:
			if between_states_timer:
				between_states_timer.stop()
		State.ATTACKING:
			velocity.x = 0
			if between_states_timer:
				between_states_timer.stop()
			if hide_weapon_timer:
				hide_weapon_timer.stop()
				hide_weapon_timer.start()
			var max_count_of_attack = 3
			if count_of_attack < max_count_of_attack:
				count_of_attack += 1
			else:
				count_of_attack = 1
			if damage_timer:
				damage_timer.start()
			if attack_cooldown_timer:
				attack_cooldown_timer.start()
		State.BIG_ATTACK:
			invulnerability = true
			hide_weapon_timer.stop()
		State.BIG_ATTACK_LANDING:
			pass
		State.KNOCKBACK:
			if between_states_timer:
				between_states_timer.stop()
		State.DEATH:
			if damage_area:
				damage_area.set_deferred("monitorable", false)
			velocity.x = 0
			death_animation_played = false
			if between_states_timer:
				between_states_timer.stop()

func handle_animations() -> void:
	if not animation_player:
		return
		
	match current_state:
		State.BIG_ATTACK:
			animation_player.play("Big_attack_prepare")
		State.BIG_ATTACK_LANDING:
			if animation_player.current_animation != "Big_attack_landing":
				animation_player.play("Big_attack_landing")
		_:
			super.handle_animations()

func _on_detection_area_body_entered(entered_body: Node2D) -> void:
	if entered_body and entered_body.is_in_group("Player"):
		target_player = entered_body
		player_in_detection_zone = true
		
		if between_states_timer:
			between_states_timer.stop()
		if emergency_timer:
			emergency_timer.stop()
		call_deferred("set_shape_detection_enabled", true)

func _on_detection_area_body_exited(exited_body: Node2D) -> void:
	if exited_body == target_player:
		target_player = null
		player_in_detection_zone = false
		player_in_attack_range = false
		can_see_player = false
		if emergency_timer:
			emergency_timer.start()
		if current_state != State.DEATH and current_state != State.ATTACKING:
			start_patrol_behavior()

func _on_attack_area_body_entered(entered_body: Node2D) -> void:
	if entered_body != self and entered_body.has_method("take_damage"):
		player_in_attack_range = true

func _on_attack_area_body_exited(exited_body: Node2D) -> void:
	if exited_body != self and exited_body.has_method("take_damage"):
		player_in_attack_range = false

func _on_damage_area_body_entered(entered_body: Node2D) -> void:
	if invulnerability:
		return
	
	if entered_body == self:
		return
	
	if entered_body.is_in_group("Player"):
		return
	
	if entered_body.has_method("get_damage"):
		var damage = entered_body.get_damage()
		var knockback_direction = (global_position - entered_body.global_position).normalized()
		if knockback_direction.x == 0:
			knockback_direction.x = randf_range(-0.1, 0.1)
		
		take_damage(damage)
		
		var damage_knockback = knockback_direction * character_data.damage_knockback_force
		damage_knockback.y = -abs(damage_knockback.y * 0.5)
		apply_knockback(damage_knockback)

func _on_between_states_timer_timeout() -> void:
	if not player_in_detection_zone and current_state != State.DEATH and current_state != State.ATTACKING and current_state != State.JUMPING:
		if current_state == State.IDLE:
			change_state(State.WALKING)
		elif current_state == State.WALKING:
			if randf() < character_data.patrol_idle_chance:
				change_state(State.IDLE)
			else:
				if randf() < 0.5:
					movement_direction *= -1
		start_patrol_behavior()

func _on_emergency_timer_timeout() -> void:
	call_deferred("set_shape_detection_enabled", false)

func set_shape_detection_enabled(enabled: bool) -> void:
	if shape_detection:
		shape_detection.disabled = not enabled

func _on_animation_finished(anim_name: String) -> void:
	if current_state == State.ATTACKING:
		if anim_name.begins_with("Attack_ground") or anim_name.begins_with("Attack_air"):
			if player_in_attack_range and target_player and is_instance_valid(target_player):
				if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
					change_state(State.ATTACKING)
				else:
					change_state(State.CHASING)
			elif player_in_detection_zone and target_player and is_instance_valid(target_player):
				change_state(State.CHASING)
			else:
				change_state(State.WALKING)
	elif current_state == State.BIG_ATTACK and anim_name == "Big_attack_prepare":
		animation_player.play("Big_attack")
	elif current_state == State.BIG_ATTACK and anim_name == "Big_attack":
		if is_on_floor():
			change_state(State.BIG_ATTACK_LANDING)
	elif anim_name == "Big_attack_prepare":
		animation_player.play("Big_attack")
	elif anim_name == "Death":
		death_animation_played = true
		queue_free()
