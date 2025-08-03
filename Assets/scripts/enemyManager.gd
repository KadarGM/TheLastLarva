extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	JUMPING,
	CHASING,
	ATTACKING,
	KNOCKBACK,
	DEATH
}

@export var enemy_data: EnemyData
var player = null

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body: Node2D = $Body

@onready var detection_area: Area2D = $Body/DetectionArea
@onready var attack_area: Area2D = $Body/AttackArea
@onready var damage_area: Area2D = $Areas/DamageArea
@onready var soft_collision_area: Area2D = $Areas/SoftCollisionArea

@onready var shape_detection: CollisionShape2D = $Body/DetectionArea/shape_detection

@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var attack_cooldown_timer: Timer = $Timers/AttackCooldownTimer
@onready var damage_timer: Timer = $Timers/DamageTimer
@onready var invulnerability_timer: Timer = $Timers/InvulnerabilityTimer
@onready var between_states_timer: Timer = $Timers/BetweenStatesTimer
@onready var emergency_timer: Timer = $Timers/EmergencyTimer

@onready var ground_check_ray: RayCast2D = $RayCasts/GroundCheckRay
@onready var ground_check_ray_2: RayCast2D = $RayCasts/GroundCheckRay2
@onready var ground_check_ray_3: RayCast2D = $RayCasts/GroundCheckRay3
@onready var left_wall_ray: RayCast2D = $RayCasts/LeftWallRay
@onready var right_wall_ray: RayCast2D = $RayCasts/RightWallRay
@onready var view_ray: RayCast2D = $RayCasts/ViewRay

@onready var sword_f: Sprite2D = $Body/body/armF_1/handF_1/swordF
@onready var sword_b: Sprite2D = $Body/body/armB_1/handB_1/swordB
@onready var sword_body: Sprite2D = $Body/body/swordBody
@onready var sword_body_2: Sprite2D = $Body/body/swordBody2

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

var health_current: int
var movement_direction: int = 1

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var target_player: Node2D = null
var player_in_attack_range: bool = false
var damage_applied_this_attack: bool = false
var count_of_attack: int = 0

@export var invulnerability: bool = false
var death_animation_played: bool = false

var player_in_detection_zone: bool = false
var chase_direction: int = 0
var can_see_player: bool = false
var has_jumped: bool = false

func _ready() -> void:
	health_current = enemy_data.health_max
	shape_detection.disabled = true
	call_deferred("init_timers")
	call_deferred("setup_raycasts")
	call_deferred("connect_signals")
	call_deferred("update_weapon_visibility", "hide")
	call_deferred("start_patrol_behavior")

func connect_signals() -> void:
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)

	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)

func _process(_delta: float) -> void:
	check_death()
	update_direction()
	update_chase_direction()
	if not player == null:
		update_view_ray(player)

func _physics_process(delta: float) -> void:
	if current_state == State.KNOCKBACK:
		handle_knockback(delta)
		handle_gravity(delta)
		handle_animations()
		move_and_slide()
		return

	if current_state == State.DEATH:
		handle_gravity(delta)
		handle_animations()
		move_and_slide()
		return

	handle_gravity(delta)
	handle_state_transitions()
	handle_current_state()
	handle_soft_collisions()
	handle_animations()
	move_and_slide()

func setup_raycasts() -> void:
	if ground_check_ray:
		ground_check_ray.target_position = Vector2(0, enemy_data.ground_check_ray_length)
		ground_check_ray.enabled = true
	if ground_check_ray_2:
		ground_check_ray_2.target_position = Vector2(0, enemy_data.ground_check_ray_length)
		ground_check_ray_2.enabled = true
	if ground_check_ray_3:
		ground_check_ray_3.target_position = Vector2(0, enemy_data.ground_check_ray_length)
		ground_check_ray_3.enabled = true

	if left_wall_ray:
		left_wall_ray.target_position = Vector2(-enemy_data.wall_ray_cast_length, 0)
		left_wall_ray.enabled = true
	if right_wall_ray:
		right_wall_ray.target_position = Vector2(enemy_data.wall_ray_cast_length, 0)
		right_wall_ray.enabled = true

func init_timers() -> void:
	if hide_weapon_timer:
		hide_weapon_timer.wait_time = enemy_data.hide_weapon_time
		hide_weapon_timer.one_shot = true
		hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)

	if attack_cooldown_timer:
		attack_cooldown_timer.wait_time = enemy_data.attack_cooldown
		attack_cooldown_timer.one_shot = true
		attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)

	if damage_timer:
		damage_timer.wait_time = enemy_data.damage_delay
		damage_timer.one_shot = true
		damage_timer.timeout.connect(_on_damage_timer_timeout)

	if invulnerability_timer:
		invulnerability_timer.wait_time = enemy_data.invulnerability_after_damage
		invulnerability_timer.one_shot = true
		invulnerability_timer.timeout.connect(_on_invulnerability_timer_timeout)

	if between_states_timer:
		between_states_timer.one_shot = true
		between_states_timer.timeout.connect(_on_between_states_timer_timeout)

	if emergency_timer:
		emergency_timer.wait_time = 4.0
		emergency_timer.one_shot = true
		emergency_timer.timeout.connect(_on_emergency_timer_timeout)

func start_patrol_behavior() -> void:
	if not player_in_detection_zone and current_state != State.DEATH and current_state != State.ATTACKING and current_state != State.JUMPING:
		var random_time = randf_range(enemy_data.patrol_state_min_time, enemy_data.patrol_state_max_time)
		between_states_timer.wait_time = random_time
		between_states_timer.start()

func update_chase_direction() -> void:
	if player_in_detection_zone and target_player and is_instance_valid(target_player):
		var x_difference = target_player.global_position.x - global_position.x
		if abs(x_difference) < enemy_data.position_tolerance:
			chase_direction = 0
		else:
			chase_direction = sign(x_difference)
	else:
		chase_direction = 0

func check_death() -> void:
	if health_current <= 0 and current_state != State.DEATH:
		change_state(State.DEATH)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	previous_state = current_state
	current_state = new_state

	match new_state:
		State.IDLE:
			velocity.x = 0
			if not player_in_detection_zone:
				start_patrol_behavior()
		State.WALKING:
			if not player_in_detection_zone:
				start_patrol_behavior()
		State.JUMPING:
			if is_on_floor() and not has_jumped:
				velocity.y = enemy_data.jump_velocity * 0.8
				has_jumped = true
		State.CHASING:
			between_states_timer.stop()
		State.ATTACKING:
			velocity.x = 0
			damage_applied_this_attack = false
			between_states_timer.stop()
			perform_attack()
		State.KNOCKBACK:
			between_states_timer.stop()
		State.DEATH:
			if damage_area:
				damage_area.monitorable = false
			velocity.x = 0
			death_animation_played = false
			between_states_timer.stop()

func handle_state_transitions() -> void:
	if current_state == State.ATTACKING or current_state == State.KNOCKBACK or current_state == State.DEATH:
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
		
		if y_difference > 0 and y_difference < abs(enemy_data.jump_velocity) * 0.8 and is_on_floor() and chase_direction != 0:
			change_state(State.JUMPING)
		elif y_difference > abs(enemy_data.jump_velocity) * 0.8 or chase_direction == 0:
			change_state(State.IDLE)
		else:
			change_state(State.CHASING)
	elif player_in_detection_zone and not can_see_player:
		if current_state != State.IDLE and current_state != State.WALKING:
			change_state(State.WALKING)
	else:
		if current_state == State.CHASING or current_state == State.IDLE:
			if not between_states_timer.time_left > 0:
				start_patrol_behavior()

func handle_current_state() -> void:
	match current_state:
		State.IDLE:
			velocity.x = 0
		State.WALKING:
			if is_on_floor() and check_edge_or_wall():
				movement_direction *= -1
			velocity.x = movement_direction * enemy_data.speed
		State.JUMPING:
			if chase_direction != 0 and can_see_player:
				velocity.x = chase_direction * enemy_data.speed
			else:
				velocity.x = move_toward(velocity.x, 0, enemy_data.speed * 0.1)
		State.CHASING:
			if chase_direction != 0:
				if check_edge_or_wall_for_chase(chase_direction):
					velocity.x = 0
				else:
					velocity.x = chase_direction * enemy_data.speed
					movement_direction = chase_direction
			else:
				velocity.x = 0
		State.ATTACKING:
			velocity.x = 0
		State.KNOCKBACK:
			pass
		State.DEATH:
			pass

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

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_knockback(delta: float) -> void:
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, enemy_data.knockback_friction * delta)

		if knockback_timer <= 0 or knockback_velocity.length() < 10:
			knockback_velocity = Vector2.ZERO
			if player_in_detection_zone:
				change_state(State.CHASING)
			else:
				change_state(State.WALKING)

func perform_attack() -> void:
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

func apply_damage_to_entities() -> void:
	if not attack_area:
		return

	var overlapping_bodies = attack_area.get_overlapping_bodies()

	if overlapping_bodies.is_empty():
		return

	var damage = 0
	match count_of_attack:
		1:
			damage = enemy_data.attack_1_dmg
		2:
			damage = enemy_data.attack_2_dmg
		3:
			damage = enemy_data.attack_3_dmg

	var base_knockback_force = enemy_data.knockback_force
	if count_of_attack == 3:
		base_knockback_force *= enemy_data.knockback_force_multiplier

	var attack_dir = -body.scale.x

	for entity in overlapping_bodies:
		if entity == self:
			continue

		var knockback_force = Vector2(
			attack_dir * base_knockback_force,
			enemy_data.jump_velocity * enemy_data.knockback_vertical_multiplier
		)

		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		if entity.has_method("apply_knockback"):
			entity.apply_knockback(knockback_force)

func take_damage(amount: int) -> void:
	if current_state == State.DEATH:
		return

	if invulnerability:
		return

	health_current -= amount
	health_current = max(0, health_current)

	invulnerability = true
	if invulnerability_timer:
		invulnerability_timer.start()

	if health_current <= 0:
		die()

func apply_knockback(force: Vector2) -> void:
	if current_state == State.DEATH or current_state == State.KNOCKBACK:
		return

	knockback_velocity = Vector2(force.x * enemy_data.knockback_force_horizontal_multiplier, force.y)
	knockback_timer = enemy_data.knockback_duration

	change_state(State.KNOCKBACK)

func die() -> void:
	change_state(State.DEATH)

func get_damage() -> float:
	return enemy_data.attack_1_dmg

func handle_animations() -> void:
	if not animation_player:
		return

	match current_state:
		State.IDLE:
			animation_player.play("Idle")
		State.WALKING, State.CHASING:
			animation_player.play("Walk")
		State.JUMPING:
			animation_player.play("Jump")
		State.ATTACKING:
			match count_of_attack:
				1:
					animation_player.play("Attack_ground_1")
					update_weapon_visibility("back")
				2:
					animation_player.play("Attack_ground_2")
					update_weapon_visibility("front")
				3:
					animation_player.play("Attack_ground_3")
					update_weapon_visibility("both")
		State.KNOCKBACK:
			animation_player.play("Jump")
		State.DEATH:
			if not death_animation_played:
				animation_player.play("Death")

func update_weapon_visibility(state: String) -> void:
	if not sword_f or not sword_b or not sword_body or not sword_body_2:
		return

	match state:
		"hide":
			sword_f.visible = false
			sword_b.visible = false
			sword_body_2.visible = true
			sword_body.visible = true
		"front":
			sword_f.visible = true
			sword_b.visible = false
			sword_body_2.visible = true
			sword_body.visible = false
		"back":
			sword_f.visible = false
			sword_b.visible = true
			sword_body_2.visible = false
			sword_body.visible = true
		"both":
			sword_f.visible = true
			sword_b.visible = true
			sword_body_2.visible = false
			sword_body.visible = false

func update_view_ray(b: Node2D) -> void:
	if player_in_detection_zone:
		view_ray.target_position = to_local(b.global_position)
		
		if not view_ray.is_colliding():
			can_see_player = true
		else:
			can_see_player = false

func _on_detection_area_body_entered(entered_body: Node2D) -> void:
	if entered_body:
		player = entered_body
		target_player = entered_body
		player_in_detection_zone = true
		between_states_timer.stop()
		emergency_timer.stop()
		call_deferred("set_shape_detection_enabled", true)

func _on_detection_area_body_exited(exited_body: Node2D) -> void:
	if exited_body == target_player:
		target_player = null
		player_in_detection_zone = false
		player_in_attack_range = false
		can_see_player = false
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

	if entered_body != self and entered_body.has_method("get_damage"):
		var damage = entered_body.get_damage()
		var knockback_direction = (global_position - entered_body.global_position).normalized()
		if knockback_direction.x == 0:
			knockback_direction.x = randf_range(-0.1, 0.1)

		take_damage(damage)

		knockback_velocity = knockback_direction * enemy_data.damage_knockback_force
		knockback_velocity.y = -abs(knockback_velocity.y * 0.5)
		knockback_timer = enemy_data.knockback_duration

		change_state(State.KNOCKBACK)

func _on_hide_weapon_timer_timeout() -> void:
	update_weapon_visibility("hide")
	count_of_attack = 1

func _on_damage_timer_timeout() -> void:
	if current_state == State.ATTACKING and not damage_applied_this_attack:
		damage_applied_this_attack = true
		apply_damage_to_entities()

func _on_invulnerability_timer_timeout() -> void:
	invulnerability = false

func _on_attack_cooldown_timer_timeout() -> void:
	pass

func _on_emergency_timer_timeout() -> void:
	call_deferred("set_shape_detection_enabled", false)

func set_shape_detection_enabled(enabled: bool) -> void:
	if shape_detection:
		shape_detection.disabled = not enabled

func _on_between_states_timer_timeout() -> void:
	if not player_in_detection_zone and current_state != State.DEATH and current_state != State.ATTACKING and current_state != State.JUMPING:
		if current_state == State.IDLE:
			change_state(State.WALKING)
		elif current_state == State.WALKING:
			if randf() < enemy_data.patrol_idle_chance:
				change_state(State.IDLE)
			else:
				if randf() < 0.5:
					movement_direction *= -1
		start_patrol_behavior()

func _on_animation_finished(anim_name: String) -> void:
	if current_state == State.ATTACKING:
		if anim_name.begins_with("Attack_ground"):
			if player_in_attack_range and target_player and is_instance_valid(target_player):
				if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
					change_state(State.ATTACKING)
				else:
					change_state(State.CHASING)
			elif player_in_detection_zone and target_player and is_instance_valid(target_player):
				change_state(State.CHASING)
			else:
				change_state(State.WALKING)
	elif anim_name == "Death":
		death_animation_played = true
		queue_free()
