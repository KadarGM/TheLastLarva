extends CharacterBody2D
class_name CharacterManager

@export_category("Components")
@export var character_data: CharacterData
@export var body_controller: Node2D
@export var animation_player: AnimationPlayer
@export var animation_state: Control
@export var camera_2d: Camera2D
@export var state_machine: CallableStateMachine
@export var control_components: Control
@export var ai_components: Control

@export_category("Utils")
@export var ray_casts_controller: RayCastsController

@export_category("Controllers")
@export var movement_controller: Node
@export var jump_controller: JumpController
@export var attack_controller: Node

@onready var big_attack_area: Area2D = $Areas/BigAttackArea
@onready var big_attack_area_2: Area2D = $Areas/BigAttackArea2
@onready var attack_area: Area2D = $Body/AttackArea
@onready var damage_area: Area2D = $Areas/DamageArea

@onready var big_jump_timer: Timer = $Timers/BigJumpTimer
@onready var big_jump_cooldown_timer: Timer = $Timers/BigJumpCooldownTimer
@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var stun_timer: Timer = $Timers/StunTimer
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldownTimer
@onready var wall_jump_control_timer: Timer = $Timers/WallJumpControlTimer
@onready var before_attack_timer: Timer = $Timers/BeforeAttackTimer
@onready var damage_timer: Timer = $Timers/DamageTimer
@onready var invulnerability_timer: Timer = $Timers/InvulnerabilityTimer

@onready var stamina_bar: ProgressBar = $GameUI/MarginContainer/HBoxContainer/VBoxContainer/StaminaBar
@onready var health_bar: ProgressBar = $GameUI/MarginContainer/HBoxContainer/VBoxContainer/HealthBar

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var invulnerability_temp: bool = false

var current_state = character_data.State.IDLE
var previous_state = character_data.State.IDLE

var health_current: int
var stamina_current: float
var stamina_regen_timer: float = 0.0

var air_time: float = 0.0
var effective_air_time: float = 0.0

var can_dash: bool = true

var big_jump_charged: bool = false
var big_jump_direction: Vector2 = Vector2.ZERO
var can_big_jump: bool = true

var dash_attack_direction: Vector2 = Vector2.ZERO

var can_wall_jump: bool = true
var has_wall_jumped: bool = false
var was_on_wall: bool = false

var count_of_attack: int = 0
var velocity_before_attack: float = 0.0
var damage_applied_this_attack: bool = false
var pending_knockback_force: Vector2 = Vector2.ZERO
var dash_attack_damaged_entities: Array = []

var big_attack_pending: bool = false
var is_high_big_attack: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var death_animation_played: bool = false
var can_charge_big_jump: bool = false

var damage_check_timer: float = 0.0
var damage_check_interval: float = 0.5

func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	health_current = character_data.health_max
	stamina_current = character_data.stamina_max
	
	setup_controllers()
	setup_timers()
	ray_casts_controller.setup_raycasts()
	setup_signals()
	set_weapon_visibility("hide")

func setup_controllers():
	if jump_controller:
		jump_controller.setup(self, state_machine)
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)
		state_machine.transition_to(CharacterData.State.IDLE)

func _on_state_changed(old_state, new_state):
	exit_current_state()
	current_state = new_state
	previous_state = old_state
	print("State changed: ", CharacterData.State.keys()[old_state], " -> ", CharacterData.State.keys()[new_state])
	enter_new_state(new_state)

func _process(delta: float) -> void:
	if current_state != character_data.State.DEATH:
		update_stamina_regeneration(delta)
		update_big_jump_stamina(delta)
		update_dash_attack_stamina(delta)
		check_continuous_damage(delta)
	update_ui()
	check_death()

func _physics_process(delta: float) -> void:
	if current_state == character_data.State.KNOCKBACK:
		process_knockback(delta)
		update_animations()
		move_and_slide()
		return
	
	if current_state == character_data.State.DEATH:
		apply_gravity(delta)
		update_animations()
		move_and_slide()
		return
	
	apply_gravity(delta)
	process_jump_release()
	check_big_attack_landing()
	update_state_transitions()
	process_current_state(delta)
	update_air_time(delta)
	update_character_direction()
	update_animations()
	move_and_slide()

func setup_timers() -> void:
	big_jump_timer.wait_time = character_data.big_jump_charge_time
	big_jump_timer.one_shot = true
	big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
	
	big_jump_cooldown_timer.wait_time = character_data.big_jump_cooldown
	big_jump_cooldown_timer.one_shot = true
	big_jump_cooldown_timer.timeout.connect(_on_big_jump_cooldown_timer_timeout)
	
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
	
	before_attack_timer.wait_time = character_data.attack_cooldown
	before_attack_timer.one_shot = true
	
	damage_timer.wait_time = character_data.damage_delay
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	invulnerability_timer.wait_time = character_data.invulnerability_after_damage
	invulnerability_timer.one_shot = true
	invulnerability_timer.timeout.connect(_on_invulnerability_timer_timeout)


func setup_signals() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.body_exited.connect(_on_attack_area_body_exited)
	damage_area.body_entered.connect(_on_damage_area_body_entered)

func transition_to_state(new_state) -> void:
	if current_state == new_state:
		return
	
	exit_current_state()
	
	previous_state = current_state
	current_state = new_state
	
	print("State changed: ", character_data.State.keys()[previous_state], " -> ", character_data.State.keys()[new_state])
	
	enter_new_state(new_state)

func exit_current_state() -> void:
	if current_state == character_data.State.ATTACKING and current_state != character_data.State.KNOCKBACK and current_state != character_data.State.DASH_ATTACK:
		pending_knockback_force = Vector2.ZERO
	
	if current_state == character_data.State.DASHING or current_state == character_data.State.BIG_ATTACK or current_state == character_data.State.DASH_ATTACK:
		invulnerability_temp = false
		print("State invulnerability_temp deactivated - Leaving state: ", character_data.State.keys()[current_state])

func enter_new_state(new_state) -> void:
	match new_state:
		character_data.State.IDLE, character_data.State.WALKING:
			jump_controller.reset_jump_state()
		character_data.State.STUNNED:
			velocity.x = 0
			cancel_big_jump_charge()
		character_data.State.WALL_JUMPING:
			wall_jump_control_timer.start()
			has_wall_jumped = true
			jump_controller.on_wall_jump()
		character_data.State.WALL_SLIDING:
			jump_controller.on_wall_jump()
			can_wall_jump = true
		character_data.State.JUMPING:
			if previous_state == character_data.State.IDLE or previous_state == character_data.State.WALKING:
				jump_controller.has_double_jump = true
				jump_controller.has_triple_jump = false
				jump_controller.jump_count = 1
		character_data.State.DOUBLE_JUMPING:
			jump_controller.jump_count = 2
			jump_controller.has_triple_jump = true
			play_animation("Double_jump")
			queue_animation("Jump")
		character_data.State.TRIPLE_JUMPING:
			jump_controller.jump_count = 3
			play_animation("Triple_jump")
			queue_animation("Jump")
		character_data.State.DASHING:
			invulnerability_temp = true
			print("character_data.State invulnerability_temp activated - DASHING")
		character_data.State.DASH_ATTACK:
			invulnerability_temp = true
			print("character_data.State invulnerability_temp activated - DASH_ATTACK")
			dash_attack_damaged_entities.clear()
			big_jump_charged = false
		character_data.State.BIG_ATTACK:
			if not character_data.can_big_attack:
				print("Can't big attack")
				return
			invulnerability_temp = true
			print("character_data.State invulnerability_temp activated - BIG_ATTACK")
			big_attack_pending = true
			hide_weapon_timer.stop()
			if air_time == 0:
				air_time = character_data.air_time_initial
				effective_air_time = character_data.air_time_initial
		character_data.State.BIG_ATTACK_LANDING:
			execute_damage_to_entities()
		character_data.State.BIG_JUMPING:
			big_jump_charged = false
		character_data.State.ATTACKING:
			velocity_before_attack = velocity.x
			damage_applied_this_attack = false
			damage_timer.start()
		character_data.State.KNOCKBACK:
			pass
		character_data.State.DEATH:
			damage_area.monitorable = false
			velocity.x = 0
			death_animation_played = false
			print("Character DEATH - Final health: ", health_current)

func update_state_transitions() -> void:
	if current_state == character_data.State.STUNNED or current_state == character_data.State.ATTACKING or current_state == character_data.State.KNOCKBACK or current_state == character_data.State.DEATH:
		return
	
	if current_state == character_data.State.BIG_JUMPING:
		check_big_jump_collision()
		check_big_jump_input_release()
		return
	
	if current_state == character_data.State.DASH_ATTACK:
		check_dash_attack_collision()
		check_dash_attack_input_release()
		return
	
	if not dash_timer.is_stopped():
		state_machine.transition_to(character_data.State.DASHING)
		return
	
	if is_on_floor():
		process_ground_state_transition()
	else:
		process_air_state_transition()

func process_ground_state_transition() -> void:
	has_wall_jumped = false
	can_wall_jump = true
	was_on_wall = false
	
	if current_state == character_data.State.BIG_ATTACK_LANDING:
		return
	
	if abs(velocity.x) > 10:
		state_machine.transition_to(character_data.State.WALKING)
	elif big_jump_timer.time_left > 0:
		state_machine.transition_to(character_data.State.CHARGING_JUMP)
	else:
		state_machine.transition_to(character_data.State.IDLE)

func process_air_state_transition() -> void:
	var left = ray_casts_controller.left_wall_ray.is_colliding()
	var right = ray_casts_controller.right_wall_ray.is_colliding()
	var can_wall_slide = false
	var is_touching_wall = left or right
	
	if is_touching_wall:
		if not was_on_wall:
			can_wall_jump = true
			was_on_wall = true
	else:
		was_on_wall = false

	if is_touching_wall and velocity.y > 0:
		if current_state == character_data.State.BIG_ATTACK or current_state == character_data.State.BIG_ATTACK_LANDING:
			can_wall_slide = false
		else:
			can_wall_slide = true
	
	if can_wall_slide:
		state_machine.transition_to(character_data.State.WALL_SLIDING)
		
	elif current_state != character_data.State.WALL_JUMPING and current_state != character_data.State.BIG_ATTACK and current_state != character_data.State.BIG_ATTACK_LANDING:
		if current_state != character_data.State.DOUBLE_JUMPING and current_state != character_data.State.JUMPING and current_state != character_data.State.TRIPLE_JUMPING:
			state_machine.transition_to(character_data.State.JUMPING)

func process_current_state(delta) -> void:
	if current_state == character_data.State.KNOCKBACK or current_state == character_data.State.DEATH:
		return
		
	var input_direction = Input.get_axis("A_left", "D_right")
	
	match current_state:
		character_data.State.IDLE, character_data.State.WALKING:
			process_ground_movement(input_direction)
			process_ground_input()
		character_data.State.JUMPING, character_data.State.DOUBLE_JUMPING, character_data.State.TRIPLE_JUMPING:
			process_air_movement(input_direction)
			process_air_input()
		character_data.State.WALL_SLIDING:
			process_wall_slide(delta)
		character_data.State.WALL_JUMPING:
			if wall_jump_control_timer.is_stopped():
				jump_controller.has_double_jump = true
				jump_controller.has_triple_jump = true
				process_air_movement(input_direction)
			process_air_input()
		character_data.State.DASHING:
			pass
		character_data.State.DASH_ATTACK:
			process_dash_attack_movement()
		character_data.State.CHARGING_JUMP:
			process_charge_jump()
		character_data.State.BIG_JUMPING:
			process_big_jump_movement()
		character_data.State.STUNNED:
			pass
		character_data.State.BIG_ATTACK:
			process_air_movement(input_direction)
		character_data.State.BIG_ATTACK_LANDING:
			velocity.x = 0
		character_data.State.ATTACKING:
			process_attack_movement()
			if before_attack_timer.is_stopped() and Input.is_action_just_pressed("L_attack"):
				execute_attack()

func process_ground_movement(input_direction: float) -> void:
	if not character_data.can_walk:
		print("Can't walk on the ground")
		return
	if input_direction:
		velocity.x = input_direction * character_data.speed
		if current_state == character_data.State.CHARGING_JUMP:
			cancel_big_jump_charge()
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed)

func process_air_movement(input_direction: float) -> void:
	if not character_data.can_walk:
		print("Can't walk in the air")
		return
	if current_state == character_data.State.BIG_ATTACK or current_state == character_data.State.BIG_ATTACK_LANDING:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * character_data.big_attack_air_friction)
		return
		
	if input_direction:
		velocity.x = input_direction * character_data.speed
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * character_data.air_movement_friction)

func process_ground_input() -> void:
	if current_state == character_data.State.STUNNED:
		return
	
	process_big_jump_input()
	
	if Input.is_action_just_pressed("W_jump"):
		if big_jump_charged and Input.is_action_pressed("J_dash"):
			execute_directional_big_jump(Vector2(0, -1))
		else:
			execute_jump()
	
	if Input.is_action_just_pressed("J_dash") and velocity.x != 0:
		perform_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		if big_jump_charged and Input.is_action_pressed("J_dash"):
			execute_dash_attack()
		else:
			perform_attack()
	
	perform_charge_big_jump()

func process_air_input() -> void:
	if Input.is_action_just_pressed("W_jump"):
		perform_air_jump()
	
	process_big_jump_input()
	
	if Input.is_action_just_pressed("J_dash") and current_state != character_data.State.ATTACKING:
		perform_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		if big_jump_charged and Input.is_action_pressed("J_dash"):
			execute_dash_attack()
		else:
			perform_air_attack()
	
	if Input.is_action_just_pressed("S_charge_jump"):
		perform_big_attack()

func process_wall_slide(delta) -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("W_jump"):
			execute_directional_big_jump(Vector2(0, -1))
			return
		elif Input.is_action_just_pressed("A_left"):
			execute_directional_big_jump(Vector2(-1, 0))
			return
		elif Input.is_action_just_pressed("D_right"):
			execute_directional_big_jump(Vector2(1, 0))
			return
	
	if Input.is_action_just_pressed("W_jump") and can_wall_jump:
		if character_data.can_wall_jump:
			execute_wall_jump()
			return
	
	if input_direction != 0 and can_wall_jump:
		if character_data.can_wall_jump:
			var wall_direction = get_wall_jump_direction()
			if (input_direction > 0 and wall_direction > 0) or (input_direction < 0 and wall_direction < 0):
				execute_wall_jump_away()
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false
	
	if Input.is_action_pressed("J_dash") and velocity.y < gravity * delta and can_big_jump:
		if Input.is_action_just_pressed("S_charge_jump"):
			cancel_big_jump_charge()
		else:
			start_big_jump_charge()
	else:
		cancel_big_jump_charge()
	
	if Input.is_action_just_pressed("J_dash"):
		if character_data.can_dash:
			perform_dash()

func process_big_jump_input() -> void:
	if big_jump_charged and Input.is_action_pressed("J_dash"):
		if Input.is_action_just_pressed("A_left"):
			execute_directional_big_jump(Vector2(-1, 0))
		elif Input.is_action_just_pressed("D_right"):
			execute_directional_big_jump(Vector2(1, 0))
	
	if big_jump_charged and Input.is_action_just_released("J_dash"):
		cancel_big_jump_charge()
		big_jump_charged = false

func process_attack_movement() -> void:
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

func process_charge_jump() -> void:
	if not Input.is_action_pressed("J_dash"):
		cancel_big_jump_charge()
	
	process_big_jump_input()
	
	if velocity.x != 0 and not big_jump_charged:
		cancel_big_jump_charge()

func process_big_jump_movement() -> void:
	if big_jump_direction.y < 0:
		velocity.x = 0
		velocity.y = -character_data.big_jump_vertical_speed
	elif big_jump_direction.x != 0:
		velocity.x = big_jump_direction.x * character_data.big_jump_horizontal_speed
		velocity.y = 0

func process_dash_attack_movement() -> void:
	if dash_attack_direction.x != 0:
		velocity.x = dash_attack_direction.x * character_data.big_jump_horizontal_speed
		velocity.y = 0

func process_knockback(delta: float) -> void:
	if current_state == character_data.State.KNOCKBACK:
		if knockback_timer > 0:
			knockback_timer -= delta
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, character_data.knockback_friction * delta)
			
			if knockback_timer <= 0 or knockback_velocity.length() < 10:
				knockback_velocity = Vector2.ZERO
				state_machine.transition_to(character_data.State.IDLE)
		else:
			state_machine.transition_to(character_data.State.IDLE)

func apply_gravity(delta: float) -> void:
	if current_state == character_data.State.BIG_JUMPING or current_state == character_data.State.KNOCKBACK or current_state == character_data.State.DASH_ATTACK:
		return
		
	if not is_on_floor():
		if current_state == character_data.State.WALL_SLIDING and (is_wall_hanging_left() or is_wall_hanging_right()):
			return
		elif current_state == character_data.State.WALL_SLIDING:
			if Input.is_action_pressed("S_charge_jump"):
				if character_data.can_wall_slide:
					velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
			elif Input.is_action_just_released("S_charge_jump"):
				velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
			else:
				velocity.y = gravity * delta / character_data.wall_slide_initial_velocity_divisor
		elif big_attack_pending and velocity.y > 0:
			velocity.y += gravity * delta * character_data.landing_multiplier
		else:
			velocity.y += gravity * delta

func process_jump_release() -> void:
	if state_machine.current_state == CharacterData.State.KNOCKBACK or state_machine.current_state == CharacterData.State.DEATH:
		return
	
	if Input.is_action_just_released("W_jump") or is_on_ceiling():
		jump_controller.handle_jump_release()

func update_air_time(delta: float) -> void:
	if not is_on_floor():
		air_time += delta
		if current_state == character_data.State.BIG_ATTACK or big_attack_pending:
			effective_air_time += delta * character_data.landing_multiplier
		else:
			effective_air_time += delta
	elif is_on_floor():
		if current_state == character_data.State.BIG_ATTACK_LANDING or big_attack_pending:
			check_stun_on_landing()
		reset_air_time()

func update_character_direction() -> void:
	if current_state == character_data.State.DEATH:
		return
		
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if current_state == character_data.State.WALL_SLIDING:
		if ray_casts_controller.left_wall_ray.is_colliding():
			body_controller.scale.x = 1
		elif ray_casts_controller.right_wall_ray.is_colliding():
			body_controller.scale.x = -1
	elif input_direction != 0 and current_state != character_data.State.DASH_ATTACK:
		body_controller.scale.x = -sign(input_direction)

func update_big_jump_stamina(delta: float) -> void:
	if current_state == character_data.State.BIG_JUMPING:
		stamina_current -= character_data.big_jump_stamina_drain_rate * delta
		if stamina_current <= 0:
			stamina_current = 0
			print("Big jump ended - Stamina depleted")
			end_big_jump()

func update_dash_attack_stamina(delta: float) -> void:
	if current_state == character_data.State.DASH_ATTACK:
		stamina_current -= character_data.dash_attack_stamina_drain_rate * delta
		if stamina_current <= 0:
			stamina_current = 0
			print("Dash attack ended - Stamina depleted")
			end_dash_attack()

func update_stamina_regeneration(delta: float) -> void:
	if stamina_current >= character_data.stamina_max:
		return
	
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
		return
	
	stamina_current += character_data.dash_stamina_cost * delta * character_data.stamina_regen_rate
	stamina_current = min(stamina_current, character_data.stamina_max)

func check_continuous_damage(delta: float) -> void:
	if not character_data.can_get_damage:
		return
	
	if character_data.invulnerability or invulnerability_temp:
		return
	
	damage_check_timer -= delta
	if damage_check_timer > 0:
		return
	
	damage_check_timer = damage_check_interval
	
	var bodies_in_area = damage_area.get_overlapping_bodies()
	for body in bodies_in_area:
		if body.has_method("get_damage") and body != self:
			var damage = body.get_damage()
			take_damage(damage, body.global_position)
			break

func execute_jump() -> void:
	if jump_controller.handle_ground_jump():
		state_machine.transition_to(CharacterData.State.JUMPING)

func execute_double_jump() -> void:
	var result = jump_controller.handle_air_jump(stamina_current)
	if result.success and result.type == "double":
		reset_air_time()
		state_machine.transition_to(CharacterData.State.DOUBLE_JUMPING)

func execute_triple_jump() -> void:
	var result = jump_controller.handle_air_jump(stamina_current)
	if result.success and result.type == "triple":
		stamina_current -= result.stamina_cost
		stamina_regen_timer = character_data.stamina_regen_delay
		reset_air_time()
		state_machine.transition_to(CharacterData.State.TRIPLE_JUMPING)

func execute_wall_jump() -> void:
	var wall_direction = get_wall_jump_direction()
	velocity.y = character_data.jump_velocity * 0.3
	velocity.x = wall_direction * character_data.wall_jump_force * character_data.wall_jump_away_multiplier
	reset_air_time()
	state_machine.transition_to(character_data.State.WALL_JUMPING)
	can_wall_jump = false

func execute_wall_jump_away() -> void:
	var wall_direction = get_wall_jump_direction()
	velocity.y = 0
	velocity.x = wall_direction * character_data.wall_jump_force * character_data.wall_jump_away_multiplier
	reset_air_time()
	state_machine.transition_to(character_data.State.WALL_JUMPING)
	can_wall_jump = false

func execute_dash_attack() -> void:
	if not character_data.can_dash_attack or not character_data.can_attack:
		print("Can't dash attack")
		return
	var attack_dir = get_attack_direction()
	dash_attack_direction = Vector2(attack_dir, 0)
	
	print("Starting dash attack in direction: ", attack_dir)
	
	state_machine.transition_to(character_data.State.DASH_ATTACK)

func execute_directional_big_jump(direction: Vector2) -> void:
	if not character_data.can_big_jump:
		print("Can't big jump")
		return
	big_jump_charged = false
	big_jump_direction = direction
	state_machine.transition_to(character_data.State.BIG_JUMPING)

func execute_attack() -> void:
	if not character_data.can_attack:
		print("Can't attack")
		return
	if not before_attack_timer.is_stopped():
		return
	
	if current_state == character_data.State.ATTACKING:
		return
	
	var max_count_of_attack = 3
	
	state_machine.transition_to(character_data.State.ATTACKING)
	
	if count_of_attack < max_count_of_attack:
		count_of_attack += 1
	else:
		count_of_attack = 1
	
	print("Performing attack ", count_of_attack, " of ", max_count_of_attack)
	
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	before_attack_timer.start()

func execute_damage_to_entities() -> void:
	if not character_data.can_take_damage:
		print("Can't take damage")
		return
		
	if current_state == character_data.State.BIG_ATTACK_LANDING:
		apply_big_attack_damage()
	else:
		apply_normal_attack_damage()

func apply_big_attack_damage() -> void:
	if not character_data.can_take_damage:
		print("Can't take damage")
		return
		
	var front_bodies = big_attack_area.get_overlapping_bodies()
	var back_bodies = big_attack_area_2.get_overlapping_bodies()
	
	var damage = character_data.big_attack_dmg
	var base_knockback_force = character_data.knockback_force * character_data.knockback_force_multiplier
	var attack_dir = get_attack_direction()
	var hit_count = 0
	
	print("Applying big attack damage - Damage: ", damage)
	print("attack dir: ", attack_dir)

	for entity in front_bodies:
		if entity == self:
			continue
		hit_count += 1
		print("Hit entity in front area: ", entity.name)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if character_data.can_take_knockback:
			var knockback_force = Vector2(
				1 * base_knockback_force * 2.0,
				character_data.jump_velocity * character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	for entity in back_bodies:
		if entity == self or entity in front_bodies:
			continue
		hit_count += 1
		print("Hit entity in back area: ", entity.name)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if character_data.can_take_knockback:
			var knockback_force = Vector2(
				-1 * base_knockback_force * 2.0,
				character_data.jump_velocity * character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier * character_data.knockback_reaction_force_multiplier,
			character_data.jump_velocity * character_data.knockback_reaction_jump_multiplier
		)
		apply_knockback(reaction_force)

func apply_normal_attack_damage() -> void:
	if not character_data.can_take_damage:
		print("Can't take damage")
		return
		
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
	
	print("Applying damage - Attack type: ", current_state, ", Damage: ", damage)
	
	var base_knockback_force = character_data.knockback_force
	if count_of_attack == 3:
		base_knockback_force *= character_data.knockback_force_multiplier
	
	var attack_dir = get_attack_direction()
	var hit_count = 0
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		
		hit_count += 1
		print("Hit entity: ", entity.name)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if character_data.can_take_knockback:
			var knockback_force = Vector2(
				attack_dir * base_knockback_force,
				character_data.jump_velocity * character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier * character_data.knockback_reaction_force_multiplier,
			character_data.jump_velocity * character_data.knockback_reaction_jump_multiplier
		)
		
		if current_state == character_data.State.ATTACKING:
			pending_knockback_force = reaction_force
		else:
			apply_knockback(reaction_force)

func perform_dash() -> void:
	if not character_data.can_dash or not can_dash:
		print("Can't dash")
		return
	
	if stamina_current < character_data.dash_stamina_cost:
		return
	
	var dash_direction = Input.get_axis("A_left", "D_right")
	if dash_direction == 0:
		return
	
	velocity.x = dash_direction * character_data.dash_speed
	velocity.y = 0
	can_dash = false
	var old_stamina = stamina_current
	stamina_current -= character_data.dash_stamina_cost
	stamina_regen_timer = character_data.stamina_regen_delay
	print("Dash stamina cost - Stamina: ", old_stamina, " -> ", stamina_current)
	
	if big_jump_charged:
		dash_timer.wait_time = character_data.dash_duration * character_data.big_jump_dash_multiplier
		big_jump_charged = false
	else:
		dash_timer.wait_time = character_data.dash_duration
	
	dash_timer.start()
	dash_cooldown_timer.start()
	state_machine.transition_to(character_data.State.DASHING)

func perform_attack() -> void:
	if not character_data.can_attack:
		print("Can't attack")
		return
	if stamina_current >= character_data.attack_stamina_cost:
		var old_stamina = stamina_current
		stamina_current -= character_data.attack_stamina_cost
		stamina_regen_timer = character_data.stamina_regen_delay
		print("Attack stamina cost - Stamina: ", old_stamina, " -> ", stamina_current)
		execute_attack()

func perform_air_attack() -> void:
	if not character_data.can_attack or not character_data.can_air_attack:
		print("Can't air attack")
		return
	if stamina_current >= character_data.attack_stamina_cost:
		var old_stamina = stamina_current
		stamina_current -= character_data.attack_stamina_cost
		stamina_regen_timer = character_data.stamina_regen_delay
		print("Attack stamina cost - Stamina: ", old_stamina, " -> ", stamina_current)
		execute_attack()

func perform_air_jump() -> void:
	if state_machine.current_state != CharacterData.State.WALL_JUMPING and state_machine.current_state != CharacterData.State.ATTACKING:
		if jump_controller.has_double_jump and jump_controller.jump_count == 1:
			execute_double_jump()
		elif jump_controller.has_triple_jump and jump_controller.jump_count == 2:
			execute_triple_jump()

func perform_big_attack() -> void:
	if not character_data.can_big_attack:
		print("Can't big attack")
		return
	var ground = ray_casts_controller.ground_check_ray.is_colliding() or ray_casts_controller.ground_check_ray_2.is_colliding() or ray_casts_controller.ground_check_ray_3.is_colliding()
	if stamina_current >= character_data.big_attack_stamina_cost:
		var old_stamina = stamina_current
		stamina_current -= character_data.big_attack_stamina_cost
		stamina_regen_timer = character_data.stamina_regen_delay
		print("Big attack stamina cost - Stamina: ", old_stamina, " -> ", stamina_current)
		is_high_big_attack = not ground
		state_machine.transition_to(character_data.State.BIG_ATTACK)

func perform_charge_big_jump() -> void:
	if not character_data.can_big_jump and not character_data.can_dash_attack:
		can_charge_big_jump = false
	elif character_data.can_big_jump and not character_data.can_dash_attack:
		can_charge_big_jump = true
	elif not character_data.can_big_jump and character_data.can_dash_attack:
		can_charge_big_jump = true
	elif character_data.can_big_jump and character_data.can_dash_attack:
		can_charge_big_jump = true

	if not can_charge_big_jump:
		return

	if Input.is_action_pressed("J_dash") and velocity.x == 0 and can_big_jump:
		start_big_jump_charge()

func start_big_jump_charge() -> void:
	if big_jump_charged or big_jump_timer.time_left > 0 or not can_big_jump:
		return
	can_big_jump = false
	big_jump_cooldown_timer.start()
	big_jump_timer.start()

func cancel_big_jump_charge() -> void:
	if big_jump_timer.time_left > 0:
		big_jump_timer.stop()
		big_jump_charged = false

func check_big_jump_collision() -> void:
	var _ceil = ray_casts_controller.ceiling_ray.is_colliding() or ray_casts_controller.ceiling_ray_2.is_colliding() or ray_casts_controller.ceiling_ray_3.is_colliding()
	var left = ray_casts_controller.left_wall_ray.is_colliding()
	var right = ray_casts_controller.right_wall_ray.is_colliding()
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
	state_machine.transition_to(character_data.State.JUMPING)

func check_dash_attack_collision() -> void:
	var left = ray_casts_controller.left_wall_ray.is_colliding()
	var right = ray_casts_controller.right_wall_ray.is_colliding()
	if dash_attack_direction.x < 0 and left:
		end_dash_attack()
	elif dash_attack_direction.x > 0 and right:
		end_dash_attack()

func check_dash_attack_input_release() -> void:
	if not Input.is_action_pressed("L_attack"):
		end_dash_attack()

func end_dash_attack() -> void:
	dash_attack_direction = Vector2.ZERO
	dash_attack_damaged_entities.clear()
	stamina_regen_timer = character_data.stamina_regen_delay
	state_machine.transition_to(character_data.State.JUMPING)
	hide_weapon_timer.stop()
	hide_weapon_timer.start()

func check_big_attack_landing() -> void:
	var near = ray_casts_controller.near_ground_ray.is_colliding() or ray_casts_controller.near_ground_ray_2.is_colliding() or ray_casts_controller.near_ground_ray_3.is_colliding()
	if current_state == character_data.State.BIG_ATTACK and big_attack_pending and near:
		state_machine.transition_to(character_data.State.BIG_ATTACK_LANDING)

func check_stun_on_landing() -> void:
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	big_attack_pending = false

func check_death() -> void:
	if health_current <= 0 and current_state != character_data.State.DEATH:
		state_machine.transition_to(character_data.State.DEATH)

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0

func get_attack_direction() -> float:
	return -body_controller.scale.x

func get_wall_jump_direction() -> float:
	if ray_casts_controller.left_wall_ray.is_colliding():
		return 1.0
	elif ray_casts_controller.right_wall_ray.is_colliding():
		return -1.0
	return 0.0

func is_wall_hanging_left() -> bool:
	var colliding = ray_casts_controller.left_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction < 0

func is_wall_hanging_right() -> bool:
	var colliding = ray_casts_controller.right_wall_ray.is_colliding()
	var input_direction = Input.get_axis("A_left", "D_right")
	return colliding and input_direction > 0

func has_nearby_enemy() -> bool:
	var overlapping_bodies = attack_area.get_overlapping_bodies()
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		return true
	return false

func apply_knockback(force: Vector2) -> void:
	if not character_data.can_get_knockback:
		print("Can't get knockback")
		return
		
	if current_state == character_data.State.BIG_ATTACK or current_state == character_data.State.BIG_ATTACK_LANDING or current_state == character_data.State.BIG_JUMPING or current_state == character_data.State.KNOCKBACK or current_state == character_data.State.DEATH or current_state == character_data.State.DASH_ATTACK:
		return
	
	knockback_velocity = Vector2(force.x * character_data.knockback_force_horizontal_multiplier, force.y)
	knockback_timer = character_data.knockback_duration
	
	state_machine.transition_to(character_data.State.KNOCKBACK)

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not character_data.can_get_damage:
		print("Can't get damage")
		return
		
	if current_state == character_data.State.DEATH:
		return
	
	if character_data.invulnerability:
		print("Damage blocked - Character has permanent invulnerability")
		return
	
	if invulnerability_temp:
		print("Damage blocked - Character is temporarily invulnerable")
		return
		
	var old_health = health_current
	health_current -= amount
	health_current = max(0, health_current)
	
	var old_stamina = stamina_current
	stamina_current -= character_data.damage_stamina_cost
	stamina_current = max(0, stamina_current)
	stamina_regen_timer = character_data.stamina_regen_delay
	
	print("Damage taken: ", amount, " - Health: ", old_health, " -> ", health_current, ", Stamina: ", old_stamina, " -> ", stamina_current)
	
	invulnerability_temp = true
	invulnerability_timer.start()
	print("Invulnerability activated for ", character_data.invulnerability_after_damage, " seconds")
	
	if character_data.can_get_knockback and current_state != character_data.State.KNOCKBACK:
		var knockback_direction: Vector2
		if attacker_position != Vector2.ZERO:
			knockback_direction = (global_position - attacker_position).normalized()
		else:
			knockback_direction = Vector2(randf_range(-1, 1), 0).normalized()
		
		if knockback_direction.x == 0:
			knockback_direction.x = randf_range(-0.5, 0.5)
		
		var damage_knockback = Vector2(
			knockback_direction.x * character_data.damage_knockback_force * 10.0,
			-abs(character_data.damage_knockback_force * 0.8)
		)
		apply_knockback(damage_knockback)

func update_animations() -> void:
	match current_state:
		character_data.State.IDLE:
			if big_jump_charged and Input.is_action_pressed("J_dash"):
				play_animation("Big_jump_charge")
			else:
				play_animation("Idle")
		character_data.State.WALKING:
			play_animation("Walk")
		character_data.State.JUMPING, character_data.State.WALL_JUMPING:
			play_animation("Jump")
		character_data.State.BIG_JUMPING:
			play_animation("Dash")
		character_data.State.BIG_ATTACK:
			if not character_data.can_big_attack:
				print("Can't big attack")
				return
			if is_high_big_attack and animation_player.current_animation != "Big_attack":
				play_animation("Big_attack_prepare")
				set_weapon_visibility("both")
		character_data.State.BIG_ATTACK_LANDING:
			if animation_player.current_animation != "Big_attack_landing":
				play_animation("Big_attack_landing")
		character_data.State.WALL_SLIDING:
			if Input.is_action_pressed("J_dash"):
				play_animation("Big_jump_wall_charge")
			else:
				play_animation("Sliding_wall")
		character_data.State.DASHING:
			play_animation("Dash")
		character_data.State.DASH_ATTACK:
			play_animation("Dash_attack")
			set_weapon_visibility("both")
		character_data.State.CHARGING_JUMP:
			play_animation("Big_jump_charge")
		character_data.State.STUNNED:
			pass
		character_data.State.KNOCKBACK:
			play_animation("Jump")
		character_data.State.DOUBLE_JUMPING, character_data.State.TRIPLE_JUMPING:
			pass
		character_data.State.ATTACKING:
			if is_on_floor():
				match count_of_attack:
					1: 
						play_animation("Attack_ground_1")
						set_weapon_visibility("back")
					2:  
						play_animation("Attack_ground_2")
						set_weapon_visibility("front")
					3:  
						play_animation("Attack_ground_3")
						set_weapon_visibility("both")
			elif not is_on_floor():
				match count_of_attack:
					1: 
						play_animation("Attack_air_1")
						set_weapon_visibility("back")
					2:  
						play_animation("Attack_air_2")
						set_weapon_visibility("front")
					3:  
						play_animation("Attack_air_3")
						set_weapon_visibility("both")
		character_data.State.DEATH:
			if not death_animation_played and animation_player.current_animation != "Death":
				animation_player.stop()
				animation_player.play("Death")
				death_animation_played = true

func play_animation(anim_name: String) -> void:
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func queue_animation(anim_name: String) -> void:
	animation_player.queue(anim_name)

func update_ui() -> void:
	stamina_bar.value = stamina_current
	stamina_bar.max_value = character_data.stamina_max
	health_bar.value = health_current
	health_bar.max_value = character_data.health_max

func set_weapon_visibility(state: String) -> void:
	match state:
		"hide":
			body_controller.sword_f.visible = false
			body_controller.sword_b.visible = false
			body_controller.sword_body_2.visible = true
			body_controller.sword_body.visible = true
		"front":
			body_controller.sword_f.visible = true
			body_controller.sword_b.visible = false
			body_controller.sword_body_2.visible = true
			body_controller.sword_body.visible = false
		"back":
			body_controller.sword_f.visible = false
			body_controller.sword_b.visible = true
			body_controller.sword_body_2.visible = false
			body_controller.sword_body.visible = true
		"both":
			body_controller.sword_f.visible = true
			body_controller.sword_b.visible = true
			body_controller.sword_body_2.visible = false
			body_controller.sword_body.visible = false

func _on_hide_weapon_timer_timeout() -> void:
	set_weapon_visibility("hide")
	count_of_attack = 1

func _on_big_jump_timer_timeout() -> void:
	big_jump_charged = true

func _on_big_jump_cooldown_timer_timeout() -> void:
	can_big_jump = true

func _on_stun_timer_timeout() -> void:
	state_machine.transition_to(character_data.State.IDLE)

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true

func _on_damage_timer_timeout() -> void:
	if not damage_applied_this_attack:
		damage_applied_this_attack = true
		execute_damage_to_entities()

func _on_invulnerability_timer_timeout() -> void:
	invulnerability_temp = false
	print("Invulnerability deactivated - Timer expired")

func _on_damage_area_body_entered(_body: Node2D) -> void:
	if not character_data.can_get_damage:
		print("Can't get damage")
		return
		
	if character_data.invulnerability:
		print("Damage area entered but character has permanent invulnerability")
		return
		
	if invulnerability_temp:
		print("Damage area entered but character is temporarily invulnerable")
		return
		
	if _body.has_method("get_damage") and _body != self:
		var damage = _body.get_damage()
		take_damage(damage, _body.global_position)

func _on_attack_area_body_entered(_body: Node2D) -> void:
	if current_state != character_data.State.DASH_ATTACK or _body == self:
		return
		
	if _body in dash_attack_damaged_entities:
		return
	
	if not character_data.can_take_damage:
		print("Can't take damage")
		return
	
	dash_attack_damaged_entities.append(_body)
	
	var damage = character_data.dash_attack_dmg
	var base_knockback_force = character_data.knockback_force * character_data.knockback_force_multiplier
	var attack_dir = get_attack_direction()
	
	print("Dash attack hit entity: ", _body.name, " - Damage: ", damage)
	
	if _body.has_method("take_damage"):
		_body.take_damage(damage)
	
	if character_data.can_take_knockback:
		var knockback_force = Vector2(
			attack_dir * base_knockback_force * 1.5,
			character_data.jump_velocity * character_data.knockback_vertical_multiplier
		)
		
		if _body.has_method("apply_knockback"):
			_body.apply_knockback(knockback_force)
	
	var reaction_force = Vector2(
		-attack_dir * base_knockback_force * character_data.knockback_reaction_multiplier,
		0
	)
	pending_knockback_force = reaction_force

func _on_attack_area_body_exited(_body: Node2D) -> void:
	pass

func _on_animation_finished(anim_name: String) -> void:
	if current_state == character_data.State.ATTACKING:
		if anim_name.begins_with("Attack_ground"):
			if pending_knockback_force.length() > 0:
				apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				velocity.x = velocity_before_attack
				state_machine.transition_to(character_data.State.IDLE)
		elif anim_name.begins_with("Attack_air"):
			if pending_knockback_force.length() > 0:
				apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				state_machine.transition_to(character_data.State.JUMPING)
	elif current_state == character_data.State.DASH_ATTACK and anim_name == "Dash_attack":
		end_dash_attack()
	elif current_state == character_data.State.BIG_ATTACK and anim_name == "Big_attack_prepare":
		play_animation("Big_attack")
	elif anim_name == "Big_attack" and (current_state == character_data.State.BIG_ATTACK_LANDING or is_on_floor()):
		if not animation_player.is_playing() or animation_player.current_animation != "Big_attack_landing":
			play_animation("Big_attack_landing")
	elif anim_name == "Big_attack_landing":
		if effective_air_time > character_data.stun_after_land_treshold:
			state_machine.transition_to(character_data.State.STUNNED)
			stun_timer.start()
		else:
			state_machine.transition_to(character_data.State.IDLE)
