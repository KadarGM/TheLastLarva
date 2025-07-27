extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	TRIPLE_JUMPING,
	WALL_SLIDING,
	WALL_JUMPING,
	DASHING,
	CHARGING_JUMP,
	BIG_JUMPING,
	STUNNED,
	ATTACKING,
	BIG_ATTACK,
	BIG_ATTACK_LANDING,
	KNOCKBACK
}

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body: Node2D = $Body
@onready var attack_area: Area2D = $AttackArea
@onready var camera_2d: Camera2D = $Camera2D

@onready var big_jump_timer: Timer = $Timers/BigJumpTimer
@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var stun_timer: Timer = $Timers/StunTimer
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldownTimer
@onready var wall_jump_control_timer: Timer = $Timers/WallJumpControlTimer
@onready var before_attack_timer = $Timers/BeforeAttackTimer

var damage_timer: Timer

@onready var ground_check_ray: RayCast2D = $RayCasts/GroundCheckRay
@onready var ground_check_ray_2: RayCast2D = $RayCasts/GroundCheckRay2
@onready var ground_check_ray_3: RayCast2D = $RayCasts/GroundCheckRay3
@onready var near_ground_ray: RayCast2D = $RayCasts/NearGroundRay
@onready var near_ground_ray_2: RayCast2D = $RayCasts/NearGroundRay2
@onready var near_ground_ray_3: RayCast2D = $RayCasts/NearGroundRay3
@onready var left_wall_ray: RayCast2D = $RayCasts/LeftWallRay
@onready var right_wall_ray: RayCast2D = $RayCasts/RightWallRay
@onready var ceiling_ray: RayCast2D = $RayCasts/CeilingRay
@onready var ceiling_ray_2: RayCast2D = $RayCasts/CeilingRay2
@onready var ceiling_ray_3: RayCast2D = $RayCasts/CeilingRay3

@onready var sword_f: Sprite2D = $Body/body/armF_1/handF_1/swordF
@onready var sword_b: Sprite2D = $Body/body/armB_1/handB_1/swordB
@onready var sword_body: Sprite2D = $Body/body/swordBody
@onready var sword_body_2: Sprite2D = $Body/body/swordBody2

@onready var stamina_bar: ProgressBar = $GameUI/MarginContainer/HBoxContainer/VBoxContainer/StaminaBar

@export var character_data: CharacterData

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_state: State = State.IDLE
var previous_state: State = State.IDLE

var stamina_regen_timer: float = 0.0
var air_time: float = 0.0
var effective_air_time: float = 0.0
var big_jump_charged: bool = false
var can_dash: bool = true
var can_double_jump: bool = true
var can_triple_jump: bool = false
var can_wall_jump: bool = true
var has_wall_jumped: bool = false
var big_attack_pending: bool = false
var is_jump_held: bool = false
var is_double_jump_held: bool = false
var is_triple_jump_held: bool = false
var is_high_big_attack: bool = false
var count_of_attack: int = 0
var big_jump_direction: Vector2 = Vector2.ZERO
var jump_count: int = 0
var was_on_wall: bool = false
var velocity_before_attack: float = 0.0
var knockback_applied_during_attack: bool = false
var pending_knockback_force: Vector2 = Vector2.ZERO
var damage_applied_this_attack: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var last_frame_state: State = State.IDLE
var last_frame_facing: float = 1.0

func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	init_timers()
	setup_raycasts()
	setup_attack_area()
	animation_player.animation_finished.connect(_on_animation_finished)
	
	update_weapon_visibility("hide")

func setup_attack_area() -> void:
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = character_data.attack_area_radius
	collision_shape.shape = circle_shape
	attack_area.add_child(collision_shape)

func _process(delta: float) -> void:
	handle_stamina_regeneration(delta)
	handle_big_jump_stamina(delta)
	update_ui()

func _physics_process(delta: float) -> void:
	
	if current_state == State.KNOCKBACK:
		handle_knockback(delta)
		handle_animations()
		move_and_slide()
		return
	
	handle_gravity(delta)
	handle_jump_release()
	check_big_attack_landing()
	handle_state_transitions()
	handle_current_state(delta)
	handle_air_time(delta)
	handle_flipping()
	handle_animations()
	move_and_slide()

func handle_flipping() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if current_state == State.WALL_SLIDING:
		if left_wall_ray.is_colliding():
			body.scale.x = 1
		elif right_wall_ray.is_colliding():
			body.scale.x = -1
	elif input_direction != 0:
		body.scale.x = -sign(input_direction)

func setup_raycasts() -> void:
	ground_check_ray.target_position = Vector2(0, character_data.ground_check_ray_length)
	ground_check_ray.enabled = true
	
	ground_check_ray_2.target_position = Vector2(0, character_data.ground_check_ray_length)
	ground_check_ray_2.enabled = true
	
	ground_check_ray_3.target_position = Vector2(0, character_data.ground_check_ray_length)
	ground_check_ray_3.enabled = true
	
	near_ground_ray.target_position = Vector2(0, character_data.near_ground_ray_length)
	near_ground_ray.enabled = true
	
	near_ground_ray_2.target_position = Vector2(0, character_data.near_ground_ray_length)
	near_ground_ray_2.enabled = true
	
	near_ground_ray_3.target_position = Vector2(0, character_data.near_ground_ray_length)
	near_ground_ray_3.enabled = true
	
	left_wall_ray.target_position = Vector2(-character_data.wall_ray_cast_length, 0)
	left_wall_ray.enabled = true
	
	right_wall_ray.target_position = Vector2(character_data.wall_ray_cast_length, 0)
	right_wall_ray.enabled = true
	
	ceiling_ray.target_position = Vector2(0, -character_data.ceiling_ray_length)
	ceiling_ray.enabled = true
	
	ceiling_ray_2.target_position = Vector2(0, -character_data.ceiling_ray_length)
	ceiling_ray_2.enabled = true
	
	ceiling_ray_3.target_position = Vector2(0, -character_data.ceiling_ray_length)
	ceiling_ray_3.enabled = true

func handle_knockback(delta: float) -> void:
	if current_state == State.KNOCKBACK:
		if knockback_timer > 0:
			knockback_timer -= delta
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, character_data.knockback_friction * delta)
			
			if knockback_timer <= 0 or knockback_velocity.length() < 10:
				knockback_velocity = Vector2.ZERO
				change_state(State.IDLE)
		else:
			change_state(State.IDLE)

func get_attack_direction() -> float:
	return -body.scale.x

func has_nearby_enemy() -> bool:
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		print("Enemy in attack area - should not use attack movement")
		return true
	return false

func apply_damage_to_entities() -> void:
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	
	if overlapping_bodies.is_empty():
		return
	
	var damage = 0
	match count_of_attack:
		1:
			damage = character_data.attack_1_dmg
		2:
			damage = character_data.attack_2_dmg
		3:
			damage = character_data.attack_3_dmg
			
	if current_state == State.BIG_ATTACK_LANDING:
		damage = character_data.big_attack_dmg
	
	var base_knockback_force = character_data.knockback_force
	if count_of_attack == 3 or current_state == State.BIG_ATTACK_LANDING:
		base_knockback_force *= character_data.knockback_force_multiplier
	
	var attack_dir = get_attack_direction()
	var total_reaction_force = Vector2.ZERO
	var hit_count = 0
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		
		hit_count += 1
		
		var knockback_force = Vector2(
			attack_dir * base_knockback_force,
			character_data.jump_velocity * character_data.knockback_vertical_multiplier
		)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		if entity.has_method("apply_knockback"):
			entity.apply_knockback(knockback_force)
		
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier * character_data.knockback_reaction_force_multiplier,
			character_data.jump_velocity * character_data.knockback_reaction_jump_multiplier
		)
		total_reaction_force += reaction_force
	
	if hit_count > 0 and total_reaction_force.length() > 0:
		if current_state == State.ATTACKING:
			pending_knockback_force = total_reaction_force
			print("Pending knockback after animation! Force: ", pending_knockback_force)
		else:
			print("Applying knockback immediately! Force: ", total_reaction_force)
			apply_knockback(total_reaction_force)
	else:
		print("No knockback - hit_count: ", hit_count, " force_length: ", total_reaction_force.length())

func apply_knockback(force: Vector2) -> void:
	if current_state == State.BIG_ATTACK or current_state == State.BIG_ATTACK_LANDING or current_state == State.BIG_JUMPING or current_state == State.KNOCKBACK:
		return
	
	knockback_velocity = Vector2(force.x * character_data.knockback_force_horizontal_multiplier, force.y)
	knockback_timer = character_data.knockback_duration
	
	change_state(State.KNOCKBACK)
	print("Knockback applied: ", knockback_velocity)

func take_damage(amount: int) -> void:
	character_data.health_current -= amount
	character_data.health_current = max(0, character_data.health_current)
	print("Player took ", amount, " damage! Health: ", character_data.health_current, "/", character_data.health_max)

func check_big_attack_landing() -> void:
	var near = near_ground_ray.is_colliding() or near_ground_ray_2.is_colliding() or near_ground_ray_3.is_colliding()
	if current_state == State.BIG_ATTACK and big_attack_pending and near:
		change_state(State.BIG_ATTACK_LANDING)

func is_wall_hanging_left() -> bool:
	var colliding = left_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction < 0

func is_wall_hanging_right() -> bool:
	var colliding = right_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction > 0

func get_wall_jump_direction() -> float:
	if left_wall_ray.is_colliding():
		return 1.0
	elif right_wall_ray.is_colliding():
		return -1.0
	return 0.0

func init_timers() -> void:
	big_jump_timer.wait_time = character_data.big_jump_charge_time
	big_jump_timer.one_shot = true
	big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
	
	hide_weapon_timer.wait_time = character_data.hide_weapon_time
	hide_weapon_timer.one_shot = true
	hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)
	
	dash_timer.wait_time = character_data.dash_duration
	dash_timer.one_shot = true
	
	dash_cooldown_timer.wait_time = character_data.dash_cooldown_time
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	
	stun_timer.wait_time = character_data.stun_time
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	
	wall_jump_control_timer.wait_time = character_data.wall_jump_control_delay
	wall_jump_control_timer.one_shot = true
	wall_jump_control_timer.timeout.connect(_on_wall_jump_control_timer_timeout)
	
	before_attack_timer.wait_time = character_data.attack_cooldown
	before_attack_timer.one_shot = true
	before_attack_timer.timeout.connect(_on_before_attack_timer_timeout)
	
	damage_timer = Timer.new()
	damage_timer.wait_time = character_data.damage_delay
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	print("[STATE CHANGE] ", State.keys()[current_state], " -> ", State.keys()[new_state])
	
	if current_state == State.ATTACKING and new_state != State.KNOCKBACK:
		pending_knockback_force = Vector2.ZERO
	
	previous_state = current_state
	current_state = new_state
	
	match new_state:
		State.IDLE, State.WALKING:
			jump_count = 0
		State.STUNNED:
			velocity.x = 0
			cancel_big_jump_charge()
		State.WALL_JUMPING:
			wall_jump_control_timer.start()
			has_wall_jumped = true
			jump_count = 0
			print("Wall jump executed!")
		State.WALL_SLIDING:
			jump_count = 0
			can_wall_jump = true
		State.JUMPING:
			if previous_state == State.IDLE or previous_state == State.WALKING:
				can_double_jump = true
				can_triple_jump = false
				jump_count = 1
		State.DOUBLE_JUMPING:
			jump_count = 2
			can_triple_jump = true
		State.TRIPLE_JUMPING:
			jump_count = 3
		State.DASHING:
			print("Dash! Stamina: ", character_data.stamina_current)
		State.BIG_ATTACK:
			big_attack_pending = true
			hide_weapon_timer.stop()
			if air_time == 0:
				air_time = character_data.air_time_initial
				effective_air_time = character_data.air_time_initial
		State.BIG_ATTACK_LANDING:
			print("Big attack landing!")
			apply_damage_to_entities()
		State.BIG_JUMPING:
			print("Big jump executed! Direction: ", big_jump_direction)
		State.ATTACKING:
			velocity_before_attack = velocity.x
			knockback_applied_during_attack = false
			damage_applied_this_attack = false
			damage_timer.start()
		State.KNOCKBACK:
			pass

func handle_state_transitions() -> void:
	if current_state == State.STUNNED or current_state == State.ATTACKING or current_state == State.KNOCKBACK:
		return
	
	if current_state == State.BIG_JUMPING:
		check_big_jump_collision()
		check_big_jump_input_release()
		return
	
	if not dash_timer.is_stopped():
		change_state(State.DASHING)
		return
	
	if is_on_floor():
		has_wall_jumped = false
		can_wall_jump = true
		was_on_wall = false
		
		if current_state == State.BIG_ATTACK_LANDING:
			return
		
		if abs(velocity.x) > 10:
			change_state(State.WALKING)
		elif big_jump_timer.time_left > 0:
			change_state(State.CHARGING_JUMP)
		else:
			change_state(State.IDLE)
	else:
		var left = false
		var right = false
		
		if left_wall_ray.is_colliding():
			left = true
		
		if right_wall_ray.is_colliding():
			right = true
		
		var can_wall_slide = false
		var is_touching_wall = left or right
		if is_touching_wall:
			if not was_on_wall:
				can_wall_jump = true
				was_on_wall = true
		else:
			was_on_wall = false

		if is_touching_wall and velocity.y > 0:
			if current_state == State.BIG_ATTACK or current_state == State.BIG_ATTACK_LANDING:
				can_wall_slide = false
			else:
				can_wall_slide = true
		
		if can_wall_slide:
			change_state(State.WALL_SLIDING)
		elif current_state != State.WALL_JUMPING and current_state != State.BIG_ATTACK and current_state != State.BIG_ATTACK_LANDING:
			if current_state != State.DOUBLE_JUMPING and current_state != State.JUMPING and current_state != State.TRIPLE_JUMPING:
				change_state(State.JUMPING)

func check_big_jump_collision() -> void:
	var _ceil = ceiling_ray.is_colliding() or ceiling_ray_2.is_colliding() or ceiling_ray_3.is_colliding()
	var left = left_wall_ray.is_colliding()
	var right = right_wall_ray.is_colliding()
	if big_jump_direction.y < 0 and _ceil:
		end_big_jump()
	elif big_jump_direction.x < 0 and left:
		end_big_jump()
	elif big_jump_direction.x > 0 and right:
		end_big_jump()

func check_big_jump_input_release() -> void:
	if big_jump_direction.x < 0 and not Input.is_action_pressed("A_left"):
		end_big_jump()
	elif big_jump_direction.x > 0 and not Input.is_action_pressed("D_right"):
		end_big_jump()
	elif big_jump_direction.y < 0 and not Input.is_action_pressed("W_jump"):
		end_big_jump()

func end_big_jump() -> void:
	big_jump_direction = Vector2.ZERO
	change_state(State.JUMPING)

func handle_current_state(delta) -> void:
	if current_state == State.KNOCKBACK:
		return
		
	var input_direction = Input.get_axis("A_left", "D_right")
	
	match current_state:
		State.IDLE, State.WALKING:
			handle_ground_movement(input_direction)
			handle_ground_actions()
		State.JUMPING, State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			handle_air_movement(input_direction)
			handle_air_actions()
		State.WALL_SLIDING:
			handle_wall_actions(delta)
		State.WALL_JUMPING:
			if wall_jump_control_timer.is_stopped():
				can_double_jump = true
				can_triple_jump = true
				handle_air_movement(input_direction)
			handle_air_actions()
		State.DASHING:
			pass
		State.CHARGING_JUMP:
			handle_charge_jump()
		State.BIG_JUMPING:
			handle_big_jump_movement()
		State.STUNNED:
			pass
		State.BIG_ATTACK:
			handle_air_movement(input_direction)
		State.BIG_ATTACK_LANDING:
			velocity.x = 0
		State.ATTACKING:
			handle_attack_movement()
			if before_attack_timer.is_stopped():
				if Input.is_action_just_pressed("L_attack"):
					perform_attack()

func handle_attack_movement() -> void:
	if has_nearby_enemy():
		velocity.x = move_toward(velocity.x, 0, character_data.attack_movement_friction * character_data.enemy_nearby_friction_multiplier)
		return
		
	if is_on_floor():
		var attack_force = character_data.attack_movement_force * character_data.ground_attack_force_multiplier
		if count_of_attack == 3:
			attack_force *= character_data.attack_movement_multiplier
		velocity.x = get_attack_direction() * attack_force
	else:
		var air_attack_force = character_data.attack_movement_force * character_data.air_attack_force_multiplier
		velocity.x = get_attack_direction() * air_attack_force
	
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, character_data.attack_movement_friction * character_data.ground_friction_multiplier)
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.attack_movement_friction * character_data.air_friction_multiplier)

func handle_big_jump_movement() -> void:
	if big_jump_direction.y < 0:
		velocity.x = 0
		velocity.y = -character_data.big_jump_vertical_speed
	elif big_jump_direction.x != 0:
		velocity.x = big_jump_direction.x * character_data.big_jump_horizontal_speed
		velocity.y = 0

func handle_big_jump_stamina(delta: float) -> void:
	if current_state == State.BIG_JUMPING:
		character_data.stamina_current -= character_data.big_jump_stamina_drain_rate * delta
		if character_data.stamina_current <= 0:
			character_data.stamina_current = 0
			end_big_jump()
			print("Big jump ended - out of stamina!")

func handle_ground_movement(input_direction: float) -> void:
	if input_direction:
		velocity.x = input_direction * character_data.speed
		if current_state == State.CHARGING_JUMP:
			cancel_big_jump_charge()
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed)

func handle_air_movement(input_direction: float) -> void:
	if current_state == State.BIG_ATTACK or current_state == State.BIG_ATTACK_LANDING:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * character_data.big_attack_air_friction)
		return
		
	if input_direction:
		velocity.x = input_direction * character_data.speed
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * character_data.air_movement_friction)

func handle_ground_actions() -> void:
	if current_state == State.STUNNED:
		return
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
		elif Input.is_action_just_pressed("W_jump"):
			perform_directional_big_jump(Vector2(0, -1))
			return
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_just_pressed("W_jump"):
		perform_jump()
	
	if Input.is_action_just_pressed("J_dash") and velocity.x != 0:
		attempt_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		perform_attack()
	
	if Input.is_action_pressed("J_dash") and velocity.x == 0:
		start_big_jump_charge()

func perform_directional_big_jump(direction: Vector2) -> void:
	big_jump_charged = false
	big_jump_direction = direction
	
	change_state(State.BIG_JUMPING)
	print("BIG JUMP! Direction: ", direction)

func handle_air_actions() -> void:
	if Input.is_action_just_pressed("W_jump"):
		if current_state != State.WALL_JUMPING and current_state != State.ATTACKING:
			if can_double_jump and jump_count == 1:
				perform_double_jump()
			elif can_triple_jump and jump_count == 2:
				perform_triple_jump()
		elif current_state == State.WALL_JUMPING:
			if can_double_jump:
				perform_double_jump()
			elif can_triple_jump:
				perform_triple_jump()
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_just_pressed("J_dash") and current_state != State.ATTACKING:
		attempt_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		perform_attack()
	
	if Input.is_action_just_pressed("S_charge_jump"):
		var ground = ground_check_ray.is_colliding() or ground_check_ray_2.is_colliding() or ground_check_ray_3.is_colliding()
		if character_data.stamina_current >= character_data.big_attack_stamina_cost:
			character_data.stamina_current -= character_data.big_attack_stamina_cost
			stamina_regen_timer = character_data.stamina_regen_delay
			is_high_big_attack = not ground
			change_state(State.BIG_ATTACK)

func handle_wall_actions(delta) -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
	
	if input_direction != 0 and can_wall_jump:
		var wall_direction = get_wall_jump_direction()
		if (input_direction > 0 and wall_direction > 0) or (input_direction < 0 and wall_direction < 0):
			perform_wall_jump_away()
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_pressed("J_dash") and velocity.y < gravity * delta:
		if Input.is_action_just_pressed("S_charge_jump"):
			cancel_big_jump_charge()
		else:
			start_big_jump_charge()
	else:
		cancel_big_jump_charge()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()

func perform_wall_jump_away() -> void:
	var wall_direction = get_wall_jump_direction()
	velocity.y = 0
	velocity.x = wall_direction * character_data.wall_jump_force * character_data.wall_jump_away_multiplier
	reset_air_time()
	change_state(State.WALL_JUMPING)
	can_wall_jump = false
	print("Wall jump away executed!")

func handle_charge_jump() -> void:
	if not Input.is_action_pressed("J_dash"):
		cancel_big_jump_charge()
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			perform_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			perform_directional_big_jump(Vector2(1, 0))
			return
		elif Input.is_action_just_pressed("W_jump"):
			perform_directional_big_jump(Vector2(0, -1))
			return
	
	if velocity.x != 0 and not big_jump_charged:
		cancel_big_jump_charge()
		print("Big jump cancelled - movement detected!")

func handle_gravity(delta: float) -> void:
	if current_state == State.BIG_JUMPING or current_state == State.KNOCKBACK:
		return
		
	if not is_on_floor():
		if current_state == State.WALL_SLIDING and (is_wall_hanging_left() or is_wall_hanging_right()):
			return
		elif current_state == State.WALL_SLIDING:
			if Input.is_action_pressed("S_charge_jump"):
				velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
			elif  Input.is_action_just_released("S_charge_jump"):
				velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
			else:
				velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
		elif big_attack_pending and velocity.y > 0:
			velocity.y += gravity * delta * character_data.landing_multiplier
		else:
			velocity.y += gravity * delta

func handle_jump_release() -> void:
	if current_state == State.KNOCKBACK:
		return
		
	if Input.is_action_just_released("W_jump") or is_on_ceiling():
		if is_jump_held and velocity.y < 0:
			velocity.y *= character_data.jump_release_multiplier
			is_jump_held = false
		elif is_double_jump_held and velocity.y < 0:
			velocity.y *= character_data.jump_release_multiplier
			is_double_jump_held = false
		elif is_triple_jump_held and velocity.y < 0:
			velocity.y *= character_data.jump_release_multiplier
			is_triple_jump_held = false

func perform_jump() -> void:
	velocity.y = character_data.jump_velocity
	is_jump_held = true
	change_state(State.JUMPING)
	print("Jump!")

func perform_double_jump() -> void:
	velocity.y = character_data.jump_velocity * character_data.double_jump_multiplier
	can_double_jump = false
	is_double_jump_held = true
	reset_air_time()
	change_state(State.DOUBLE_JUMPING)
	animation_player.play("Double_jump")
	animation_player.queue("Jump")
	print("Double jump!")

func perform_triple_jump() -> void:
	velocity.y = character_data.jump_velocity * character_data.triple_jump_multiplier
	can_triple_jump = false
	is_triple_jump_held = true
	reset_air_time()
	change_state(State.TRIPLE_JUMPING)
	animation_player.play("Triple_jump")
	animation_player.queue("Jump")
	print("Triple jump!")

func perform_wall_jump() -> void:
	velocity.x = get_wall_jump_direction() * character_data.wall_jump_force
	reset_air_time()
	change_state(State.WALL_JUMPING)

func attempt_dash() -> void:
	if not can_dash:
		print("Dash on cooldown!")
		return
	
	if character_data.stamina_current < character_data.stamina_cost:
		print("Not enough stamina for dash! Current: ", character_data.stamina_current, "/", character_data.stamina_cost)
		return
	
	var dash_direction = Input.get_axis("A_left", "D_right")
	if dash_direction == 0:
		return
	
	velocity.x = dash_direction * character_data.dash_speed
	velocity.y = 0
	can_dash = false
	character_data.stamina_current -= character_data.stamina_cost
	stamina_regen_timer = character_data.stamina_regen_delay
	
	if big_jump_charged:
		dash_timer.wait_time = character_data.dash_duration * character_data.big_jump_dash_multiplier
		big_jump_charged = false
		print("BIG JUMP!")
	else:
		dash_timer.wait_time = character_data.dash_duration
	
	dash_timer.start()
	dash_cooldown_timer.start()
	change_state(State.DASHING)

func perform_attack() -> void:
	if not before_attack_timer.is_stopped():
		return
	
	if current_state == State.ATTACKING:
		print("Already attacking - ignoring additional attack input")
		return
	
	var max_count_of_attack = 3
	
	change_state(State.ATTACKING)
	
	if count_of_attack < max_count_of_attack:
		count_of_attack += 1
	else:
		count_of_attack = 1
	
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	before_attack_timer.start()

func start_big_jump_charge() -> void:
	if big_jump_charged or big_jump_timer.time_left > 0:
		return
	big_jump_timer.start()
	print("BIG JUMP CHARGING STARTED - Timer: ", character_data.big_jump_charge_time, "s")

func cancel_big_jump_charge() -> void:
	if big_jump_timer.time_left > 0:
		big_jump_timer.stop()
		big_jump_charged = false
		print("BIG JUMP CANCELLED - Time left: ", big_jump_timer.time_left, "s")

func handle_air_time(delta: float) -> void:
	if not is_on_floor():
		air_time += delta
		if current_state == State.BIG_ATTACK or big_attack_pending:
			effective_air_time += delta * character_data.landing_multiplier
		else:
			effective_air_time += delta
	elif is_on_floor():
		if current_state == State.BIG_ATTACK_LANDING or big_attack_pending:
			check_stun_on_landing()
		reset_air_time()

func check_stun_on_landing() -> void:
	print("Total air time: ", air_time, "s")
	print("Effective air time: ", effective_air_time, "s")
	
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	
	big_attack_pending = false

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0

func handle_animations() -> void:
	match current_state:
		State.IDLE:
			if big_jump_charged and Input.is_action_pressed("J_dash"):
				animation_player.play("Big_jump_charge")
			else:
				animation_player.play("Idle")
		State.WALKING:
			animation_player.play("Walk")
		State.JUMPING, State.WALL_JUMPING:
			animation_player.play("Jump")
		State.BIG_JUMPING:
			animation_player.play("Dash")
		State.BIG_ATTACK:
			if is_high_big_attack and animation_player.current_animation != "Big_attack":
				animation_player.play("Big_attack_prepare")
				update_weapon_visibility("both")
		State.BIG_ATTACK_LANDING:
			if animation_player.current_animation != "Big_attack_landing":
				animation_player.play("Big_attack_landing")
		State.WALL_SLIDING:
			if (big_jump_timer.time_left > 0) or (big_jump_charged and Input.is_action_pressed("J_dash")):
				animation_player.play("Big_jump_wall_charge")
			else:
				animation_player.play("Sliding_wall")
		State.DASHING:
			animation_player.play("Dash")
		State.CHARGING_JUMP:
			animation_player.play("Big_jump_charge")
		State.STUNNED:
			pass
		State.KNOCKBACK:
			animation_player.play("Jump")
		State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			pass
		State.ATTACKING:
			if is_on_floor():
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
			else:
				match count_of_attack:
					1: 
						animation_player.play("Attack_air_1")
						update_weapon_visibility("back")
					2:  
						animation_player.play("Attack_air_2")
						update_weapon_visibility("front")
					3:  
						animation_player.play("Attack_air_3")
						update_weapon_visibility("both")

func handle_stamina_regeneration(delta: float) -> void:
	if character_data.stamina_current >= character_data.stamina_max:
		return
	
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
		return
	
	character_data.stamina_current += character_data.stamina_cost * delta * character_data.stamina_regen_rate
	character_data.stamina_current = min(character_data.stamina_current, character_data.stamina_max)

func update_ui() -> void:
	stamina_bar.value = character_data.stamina_current
	stamina_bar.max_value = character_data.stamina_max

func update_weapon_visibility(state: String) -> void:
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

func _on_hide_weapon_timer_timeout() -> void:
	update_weapon_visibility("hide")
	count_of_attack = 1

func _on_big_jump_timer_timeout() -> void:
	big_jump_charged = true
	print("BIG JUMP FULLY CHARGED!")

func _on_stun_timer_timeout() -> void:
	change_state(State.IDLE)
	print("Stun ended!")

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true
	print("Dash ready!")

func _on_wall_jump_control_timer_timeout() -> void:
	pass

func _on_before_attack_timer_timeout() -> void:
	pass

func _on_damage_timer_timeout() -> void:
	if current_state == State.ATTACKING and not damage_applied_this_attack:
		damage_applied_this_attack = true
		apply_damage_to_entities()

func _on_animation_finished(anim_name: String) -> void:
	if current_state == State.ATTACKING:
		if anim_name.begins_with("Attack_ground"):
			if pending_knockback_force.length() > 0:
				apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				velocity.x = velocity_before_attack
				change_state(State.IDLE)
		elif anim_name.begins_with("Attack_air"):
			if pending_knockback_force.length() > 0:
				apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				change_state(State.JUMPING)
	elif current_state == State.BIG_ATTACK and anim_name == "Big_attack_prepare":
		animation_player.play("Big_attack")
	elif anim_name == "Big_attack" and (current_state == State.BIG_ATTACK_LANDING or is_on_floor()):
		if not animation_player.is_playing() or animation_player.current_animation != "Big_attack_landing":
			animation_player.play("Big_attack_landing")
	elif anim_name == "Big_attack_landing":
		if effective_air_time > character_data.stun_after_land_treshold:
			change_state(State.STUNNED)
			stun_timer.start()
		else:
			change_state(State.IDLE)
