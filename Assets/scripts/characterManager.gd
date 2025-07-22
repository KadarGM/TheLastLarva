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
	BIG_ATTACK_LANDING
}

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2
@onready var body: Node2D = $Body

@onready var big_jump_timer: Timer = $Timers/BigJumpTimer
@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var stun_timer: Timer = $Timers/StunTimer
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldownTimer
@onready var wall_jump_control_timer: Timer = $Timers/WallJumpControlTimer
@onready var before_attack_timer = $Timers/BeforeAttackTimer

@onready var ground_check_ray: RayCast2D = $RayCasts/GroundCheckRay
@onready var near_ground_ray: RayCast2D = $RayCasts/NearGroundRay
@onready var left_wall_ray: RayCast2D = $RayCasts/LeftWallRay
@onready var right_wall_ray: RayCast2D = $RayCasts/RightWallRay
@onready var ceiling_ray: RayCast2D = $RayCasts/CeilingRay

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
var hide_weapon: bool = true
var can_dash: bool = true
var can_double_jump: bool = true
var can_triple_jump: bool = false
var can_wall_jump: bool = true
var has_wall_jumped: bool = false
var s_was_clicked: bool = false
var big_attack_pending: bool = false
var is_jump_held: bool = false
var is_double_jump_held: bool = false
var is_triple_jump_held: bool = false
var double_jump_animation_played: bool = false
var is_high_big_attack: bool = false
var animation_set: bool = false
var count_of_attack: int = 0
var big_jump_direction: Vector2 = Vector2.ZERO
var jump_count: int = 0
var was_on_wall: bool = false
var current_animation: String = ""

func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	init_timers()
	setup_raycasts()

func _process(delta: float) -> void:
	handle_stamina_regeneration(delta)
	handle_big_jump_stamina(delta)
	update_ui()

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jump_release()
	check_big_attack_landing()
	handle_state_transitions()
	handle_current_state()
	handle_air_time(delta)
	handle_animations()
	handle_body_flipping()
	move_and_slide()

func setup_raycasts() -> void:
	ground_check_ray.target_position = Vector2(0, character_data.ground_check_ray_length)
	ground_check_ray.enabled = true
	
	near_ground_ray.target_position = Vector2(0, character_data.near_ground_ray_length)
	near_ground_ray.enabled = true
	
	left_wall_ray.target_position = Vector2(-character_data.wall_ray_cast_length, 0)
	left_wall_ray.enabled = true
	
	right_wall_ray.target_position = Vector2(character_data.wall_ray_cast_length, 0)
	right_wall_ray.enabled = true
	
	if ceiling_ray:
		ceiling_ray.target_position = Vector2(0, -character_data.ceiling_ray_length)
		ceiling_ray.enabled = true

func check_big_attack_landing() -> void:
	if current_state == State.BIG_ATTACK and is_high_big_attack and near_ground_ray.is_colliding():
		change_state(State.BIG_ATTACK_LANDING)

func is_wall_sliding_left() -> bool:
	return left_wall_ray.is_colliding() and velocity.y > 0

func is_wall_sliding_right() -> bool:
	return right_wall_ray.is_colliding() and velocity.y > 0

func is_wall_hanging_left() -> bool:
	var input_direction = Input.get_axis("A_left", "D_right")
	return left_wall_ray.is_colliding() and input_direction < 0

func is_wall_hanging_right() -> bool:
	var input_direction = Input.get_axis("A_left", "D_right")
	return right_wall_ray.is_colliding() and input_direction > 0

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

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state
	animation_set = false
	
	match new_state:
		State.IDLE, State.WALKING:
			double_jump_animation_played = false
			jump_count = 0
		State.STUNNED:
			velocity.x = 0
			cancel_big_jump_charge()
			print("STUNNED for ", character_data.stun_time, "s!")
		State.WALL_JUMPING:
			wall_jump_control_timer.start()
			has_wall_jumped = true
			jump_count = 0
			print("Wall jump executed!")
		State.WALL_SLIDING:
			#can_double_jump = true
			#can_triple_jump = false
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
			hide_weapon = false
			hide_weapon_timer.stop()
			print("Big attack prepared!")
		State.BIG_ATTACK_LANDING:
			print("Big attack landing!")
		State.BIG_JUMPING:
			print("Big jump executed! Direction: ", big_jump_direction)

func handle_state_transitions() -> void:
	if current_state == State.STUNNED:
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
		
		if abs(velocity.x) > 10:
			change_state(State.WALKING)
		elif big_jump_timer.time_left > 0:
			change_state(State.CHARGING_JUMP)
		else:
			change_state(State.IDLE)
	else:
		var can_wall_slide = false
		var is_touching_wall = left_wall_ray.is_colliding() or right_wall_ray.is_colliding()

		if is_touching_wall:
			if not was_on_wall:
				can_wall_jump = true
				was_on_wall = true
		else:
			was_on_wall = false

		if is_touching_wall and velocity.y > 0:
			if current_state == State.BIG_ATTACK:
				can_wall_slide = false
			else:
				can_wall_slide = true
		
		if can_wall_slide:
			change_state(State.WALL_SLIDING)
		elif current_state != State.WALL_JUMPING and current_state != State.BIG_ATTACK and current_state != State.BIG_ATTACK_LANDING:
			if current_state != State.DOUBLE_JUMPING and current_state != State.JUMPING and current_state != State.TRIPLE_JUMPING:
				change_state(State.JUMPING)

func check_big_jump_collision() -> void:
	if big_jump_direction.y < 0 and ceiling_ray.is_colliding():
		end_big_jump()
	elif big_jump_direction.x < 0 and left_wall_ray.is_colliding():
		end_big_jump()
	elif big_jump_direction.x > 0 and right_wall_ray.is_colliding():
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

func handle_current_state() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	match current_state:
		State.IDLE, State.WALKING:
			handle_ground_movement(input_direction)
			handle_ground_actions()
		State.JUMPING, State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			handle_air_movement(input_direction)
			handle_air_actions()
		State.WALL_SLIDING:
			#handle_wall_slide()
			handle_wall_actions()
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
			handle_air_movement(input_direction)

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
		velocity.x = move_toward(velocity.x, 0, character_data.speed * 0.1)
		return
		
	if input_direction:
		velocity.x = input_direction * character_data.speed
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * 0.1)

func handle_ground_actions() -> void:
	if current_state == State.STUNNED:
		return
	
	if big_jump_charged:
		if Input.is_action_pressed("J_dash"):
			if Input.is_action_pressed("A_left"):
				perform_directional_big_jump(Vector2(-1, 0))
				return
			elif Input.is_action_pressed("D_right"):
				perform_directional_big_jump(Vector2(1, 0))
				return
			elif Input.is_action_pressed("W_jump"):
				perform_directional_big_jump(Vector2(0, -1))
				return
	
	if Input.is_action_just_pressed("W_jump"):
		perform_jump()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		perform_attack()
	
	if Input.is_action_pressed("S_charge_jump") and velocity.x == 0:
		start_big_jump_charge()

func perform_directional_big_jump(direction: Vector2) -> void:
	big_jump_charged = false
	big_jump_direction = direction
	
	change_state(State.BIG_JUMPING)
	print("BIG JUMP! Direction: ", direction)

func handle_air_actions() -> void:
	if Input.is_action_just_pressed("W_jump"):
		if current_state != State.WALL_JUMPING:
			if can_double_jump and jump_count == 1:
				perform_double_jump()
			elif can_triple_jump and jump_count == 2:
				perform_triple_jump()
		else:
			if can_double_jump:
				perform_double_jump()
			elif can_triple_jump:
				perform_triple_jump()
	
	if big_jump_charged:
		if Input.is_action_pressed("J_dash"):
			if Input.is_action_pressed("A_left"):
				perform_directional_big_jump(Vector2(-1, 0))
				return
			elif Input.is_action_pressed("D_right"):
				perform_directional_big_jump(Vector2(1, 0))
				return
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		perform_attack()
	
	if Input.is_action_just_pressed("S_charge_jump"):
		if character_data.stamina_current >= character_data.big_attack_stamina_cost:
			character_data.stamina_current -= character_data.big_attack_stamina_cost
			stamina_regen_timer = character_data.stamina_regen_delay
			is_high_big_attack = not ground_check_ray.is_colliding()
			change_state(State.BIG_ATTACK)
		else:
			print("Not enough stamina for big attack!")

func handle_wall_actions() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	#if Input.is_action_just_pressed("W_jump") and can_wall_jump:
		#perform_wall_jump()
	if input_direction != 0 and can_wall_jump:
		var wall_direction = get_wall_jump_direction()
		if (input_direction > 0 and wall_direction > 0) or (input_direction < 0 and wall_direction < 0):
			perform_wall_jump_away()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()

func perform_wall_jump_away() -> void:
	var wall_direction = get_wall_jump_direction()
	velocity.y = 0
	velocity.x = wall_direction * character_data.wall_jump_force * 2
	#can_double_jump = false
	#can_triple_jump = false
	#jump_count = 0
	reset_air_time()
	change_state(State.WALL_JUMPING)
	can_wall_jump = false
	print("Wall jump away executed!")

#func handle_wall_slide() -> void:
	#if is_wall_hanging_left() or is_wall_hanging_right():
		#velocity.y = 0
	#else:
		#velocity.y = min(velocity.y, gravity * character_data.wall_slide_gravity_multiplier)

func handle_charge_jump() -> void:
	if Input.is_action_just_released("S_charge_jump") and velocity.x != 0:
		cancel_big_jump_charge()

	if velocity.x != 0:
		cancel_big_jump_charge()
		print("Big jump cancelled - movement detected!")

func handle_gravity(delta: float) -> void:
	if current_state == State.BIG_JUMPING:
		return
		
	if not is_on_floor():
		if current_state == State.WALL_SLIDING and (is_wall_hanging_left() or is_wall_hanging_right()):
			return
		elif current_state == State.WALL_SLIDING:
			if Input.is_action_pressed("S_charge_jump"):
				velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
			elif  Input.is_action_just_released("S_charge_jump"):
				velocity.y = gravity * delta / 2
			else:
				velocity.y = gravity * delta / 2
		elif big_attack_pending and velocity.y > 0:
			velocity.y += gravity * delta * character_data.landing_multiplier
		else:
			velocity.y += gravity * delta

func handle_jump_release() -> void:
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
	animation_player.play("Double_jump")
	animation_player.queue("Jump")
	print("Triple jump!")

func perform_wall_jump() -> void:
	#velocity.y += 500
	velocity.x = get_wall_jump_direction() * character_data.wall_jump_force
	#can_double_jump = true
	#can_triple_jump = false
	#jump_count = 0
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
		print("BIG DASH!")
	else:
		dash_timer.wait_time = character_data.dash_duration
	
	dash_timer.start()
	dash_cooldown_timer.start()
	change_state(State.DASHING)

func perform_attack() -> void:
	if not before_attack_timer.is_stopped():
		return
	if count_of_attack < 2:
		count_of_attack += 1
	else:
		count_of_attack = 0
	set_attack(count_of_attack)
	hide_weapon = false
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	before_attack_timer.start()
	print("Attack! Played animation: ", animation_player_2.assigned_animation)

func set_attack(count) -> void:
	match count:
		0: animation_player_2.play("Attack_1")
		1: animation_player_2.play("Attack_2")
		2: animation_player_2.play("Attack_3")

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
	if not is_on_floor() and not (left_wall_ray.is_colliding() or right_wall_ray.is_colliding()):
		air_time += delta
		if big_attack_pending:
			s_was_clicked = true
			effective_air_time += delta * character_data.landing_multiplier
		else:
			s_was_clicked = false
			effective_air_time += delta
	elif is_on_floor() and air_time > 0:
		check_stun_on_landing()
		reset_air_time()
	elif left_wall_ray.is_colliding() or right_wall_ray.is_colliding():
		reset_air_time()

func check_stun_on_landing() -> void:
	print("Total air time: ", air_time, "s")
	print("Effective air time: ", effective_air_time, "s")
	
	if big_attack_pending:
		flip_body()
		animation_player.play("Landing")
		
		animation_player_2.play("Big_attack")
		animation_player_2.queue("Big_attack_rotate_weapons")
		
		hide_weapon = false
		hide_weapon_timer.stop()
		hide_weapon_timer.start()
		if effective_air_time > character_data.stun_after_land_treshold:
			change_state(State.STUNNED)
			stun_timer.start()
		big_attack_pending = false

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0
	double_jump_animation_played = false

func handle_animations() -> void:
	var target_animation = ""
	
	match current_state:
		State.IDLE:
			target_animation = "Idle"
		State.WALKING:
			target_animation = "Walk"
		State.JUMPING, State.WALL_JUMPING, State.BIG_JUMPING:
			target_animation = "Jump"
		State.BIG_ATTACK:
			if is_high_big_attack:
				target_animation = "Big_attack_prepare"
		State.BIG_ATTACK_LANDING:
			target_animation = "Big_attack_landing"
		State.WALL_SLIDING:
			target_animation = "Sliding_wall"
		State.DASHING:
			target_animation = "Dash"
		State.CHARGING_JUMP:
			target_animation = "Big_jump_charge"
		State.STUNNED:
			target_animation = "Landing"
		State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			target_animation = "Jump"
	
	if target_animation != "" and target_animation != current_animation:
		current_animation = target_animation
		animation_player.play(target_animation)
		
		if current_state == State.BIG_ATTACK and is_high_big_attack:
			animation_player.queue("Big_attack")
		elif current_state == State.BIG_ATTACK_LANDING:
			animation_player.queue("Landing")

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
	update_weapon_visibility()

func update_weapon_visibility() -> void:
	sword_f.visible = not hide_weapon
	sword_b.visible = not hide_weapon
	sword_body_2.visible = hide_weapon
	sword_body.visible = hide_weapon

func handle_body_flipping() -> void:
	match current_state:
		State.WALL_SLIDING:
			if left_wall_ray.is_colliding():
				body.scale.x = 1
			elif right_wall_ray.is_colliding():
				body.scale.x = -1
		State.WALL_JUMPING:
			if wall_jump_control_timer.time_left > 0:
				var wall_direction = get_wall_jump_direction()
				if wall_direction != 0:
					body.scale.x = wall_direction
			else:
				var input_direction = Input.get_axis("A_left", "D_right")
				if input_direction != 0:
					body.scale.x = 1 if input_direction < 0 else -1
				elif velocity.x != 0:
					body.scale.x = 1 if velocity.x < 0 else -1
		State.BIG_JUMPING:
			if big_jump_direction.x != 0:
				body.scale.x = 1 if big_jump_direction.x < 0 else -1
		_:
			var input_direction = Input.get_axis("A_left", "D_right")
			if input_direction != 0:
				body.scale.x = 1 if input_direction < 0 else -1
			elif velocity.x != 0:
				body.scale.x = 1 if velocity.x < 0 else -1

func flip_body() -> void:
	if velocity.x != 0:
		body.scale.x = 1 if velocity.x < 0 else -1

func flip_body_for_wall() -> void:
	if left_wall_ray.is_colliding():
		body.scale.x = -1
	elif right_wall_ray.is_colliding():
		body.scale.x = 1

func _on_hide_weapon_timer_timeout() -> void:
	hide_weapon = true
	count_of_attack = 0

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

func _on_double_jump_animation_finished(anim_name: String) -> void:
	if anim_name == "Double_jump" and (current_state == State.DOUBLE_JUMPING or current_state == State.TRIPLE_JUMPING):
		animation_player.play("Jump")
