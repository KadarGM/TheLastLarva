extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	CHASING,
	ATTACKING,
	KNOCKBACK,
	DEATH
}

@export var enemy_data: EnemyData

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body: Node2D = $Body

@onready var detection_area: Area2D = $Areas/DetectionArea
@onready var attack_area: Area2D = $Body/AttackArea
@onready var damage_area: Area2D = $Areas/DamageArea

@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var attack_cooldown_timer: Timer = $Timers/AttackCooldownTimer
@onready var damage_timer: Timer = $Timers/DamageTimer
@onready var invulnerability_timer: Timer = $Timers/InvulnerabilityTimer

@onready var ground_check_ray: RayCast2D = $RayCasts/GroundCheckRay
@onready var ground_check_ray_2: RayCast2D = $RayCasts/GroundCheckRay2
@onready var ground_check_ray_3: RayCast2D = $RayCasts/GroundCheckRay3
@onready var left_wall_ray: RayCast2D = $RayCasts/LeftWallRay
@onready var right_wall_ray: RayCast2D = $RayCasts/RightWallRay

@onready var sword_f: Sprite2D = $Body/body/armF_1/handF_1/swordF
@onready var sword_b: Sprite2D = $Body/body/armB_1/handB_1/swordB
@onready var sword_body: Sprite2D = $Body/body/swordBody
@onready var sword_body_2: Sprite2D = $Body/body/swordBody2

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var current_state: State = State.WALKING
var previous_state: State = State.WALKING

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

func _ready() -> void:
	if not enemy_data:
		enemy_data = EnemyData.new()
	health_current = enemy_data.health_max
	call_deferred("init_timers")
	call_deferred("setup_raycasts")
	call_deferred("connect_signals")
	call_deferred("update_weapon_visibility", "hide")

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
	handle_animations()
	move_and_slide()

func setup_raycasts() -> void:
	if ground_check_ray:
		ground_check_ray.target_position = Vector2(0, enemy_data.ground_check_ray_length)
		ground_check_ray.enabled = true
	if ground_check_ray_2:
		ground_check_ray_2.target_position = Vector2(-30, enemy_data.ground_check_ray_length)
		ground_check_ray_2.enabled = true
	if ground_check_ray_3:
		ground_check_ray_3.target_position = Vector2(30, enemy_data.ground_check_ray_length)
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
		State.WALKING:
			pass
		State.CHASING:
			pass
		State.ATTACKING:
			velocity.x = 0
			damage_applied_this_attack = false
			perform_attack()
		State.KNOCKBACK:
			pass
		State.DEATH:
			if damage_area:
				damage_area.monitorable = false
			velocity.x = 0
			death_animation_played = false

func handle_state_transitions() -> void:
	if current_state == State.ATTACKING or current_state == State.KNOCKBACK or current_state == State.DEATH:
		return
	
	if player_in_attack_range and target_player and is_instance_valid(target_player):
		if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
			change_state(State.ATTACKING)
		return
	
	if target_player != null and is_instance_valid(target_player):
		change_state(State.CHASING)
	else:
		change_state(State.WALKING)

func handle_current_state() -> void:
	match current_state:
		State.IDLE:
			velocity.x = 0
		State.WALKING:
			if is_on_floor() and check_edge_or_wall():
				movement_direction *= -1
			velocity.x = movement_direction * enemy_data.speed
		State.CHASING:
			if target_player and is_instance_valid(target_player):
				var direction_to_player = sign(target_player.global_position.x - global_position.x)
				if direction_to_player != 0:
					if is_on_floor() and check_edge_or_wall_for_chase(direction_to_player):
						velocity.x = 0
					else:
						velocity.x = direction_to_player * enemy_data.speed
						movement_direction = direction_to_player
		State.ATTACKING:
			velocity.x = 0
		State.KNOCKBACK:
			pass
		State.DEATH:
			pass

func check_edge_or_wall() -> bool:
	if movement_direction > 0:
		if right_wall_ray and right_wall_ray.is_colliding():
			return true
		if ground_check_ray and ground_check_ray.is_colliding() and ground_check_ray_3 and not ground_check_ray_3.is_colliding():
			return true
	else:
		if left_wall_ray and left_wall_ray.is_colliding():
			return true
		if ground_check_ray and ground_check_ray.is_colliding() and ground_check_ray_2 and not ground_check_ray_2.is_colliding():
			return true
	return false

func check_edge_or_wall_for_chase(direction: float) -> bool:
	if direction > 0:
		if right_wall_ray and right_wall_ray.is_colliding():
			return true
		if ground_check_ray and ground_check_ray.is_colliding() and ground_check_ray_3 and not ground_check_ray_3.is_colliding():
			return true
	else:
		if left_wall_ray and left_wall_ray.is_colliding():
			return true
		if ground_check_ray and ground_check_ray.is_colliding() and ground_check_ray_2 and not ground_check_ray_2.is_colliding():
			return true
	return false

func update_direction() -> void:
	if current_state == State.DEATH:
		return
	
	body.scale.x = -movement_direction

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

func _on_detection_area_body_entered(entered_body: Node2D) -> void:
	if entered_body.has_method("get_damage"):
		target_player = entered_body

func _on_detection_area_body_exited(exited_body: Node2D) -> void:
	if exited_body == target_player:
		target_player = null

func _on_attack_area_body_entered(entered_body: Node2D) -> void:
	if entered_body.has_method("take_damage") and entered_body != self:
		player_in_attack_range = true

func _on_attack_area_body_exited(exited_body: Node2D) -> void:
	if exited_body.has_method("take_damage") and exited_body != self:
		player_in_attack_range = false

func _on_damage_area_body_entered(entered_body: Node2D) -> void:
	if invulnerability:
		return
		
	if entered_body.has_method("get_damage") and entered_body != self:
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

func _on_animation_finished(anim_name: String) -> void:
	if current_state == State.ATTACKING:
		if anim_name.begins_with("Attack_ground"):
			if player_in_attack_range and target_player and is_instance_valid(target_player):
				if attack_cooldown_timer and attack_cooldown_timer.is_stopped():
					change_state(State.ATTACKING)
				else:
					change_state(State.CHASING)
			elif target_player and is_instance_valid(target_player):
				change_state(State.CHASING)
			else:
				change_state(State.WALKING)
	elif anim_name == "Death":
		death_animation_played = true
		queue_free()
