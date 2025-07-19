extends CharacterBody2D

enum State {
	IDLE,
	WALKING,
	JUMPING,
	DOUBLE_JUMPING,
	WALL_SLIDING,
	WALL_JUMPING,
	DASHING,
	CHARGING_JUMP,
	STUNNED,
	ATTACKING
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
var can_wall_jump: bool = true
var wall_jump_used: bool = false
var has_wall_jumped: bool = false
var s_was_clicked: bool = false


func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	init_timers()

func _process(delta: float) -> void:
	handle_stamina_regeneration(delta)
	update_ui()

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_state_transitions()
	handle_current_state()
	handle_air_time(delta)
	handle_animations()
	move_and_slide()

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

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	previous_state = current_state
	current_state = new_state	
	match new_state:
		State.STUNNED:
			velocity.x = 0
			print("STUNNED for ", character_data.stun_time, "s!")
		State.WALL_JUMPING:
			wall_jump_control_timer.start()
			has_wall_jumped = true
			can_wall_jump = false
			print("Wall jump executed!")
		State.JUMPING:
			if previous_state == State.IDLE or previous_state == State.WALKING:
				can_double_jump = true
		State.DASHING:
			print("Dash! Stamina: ", character_data.stamina_current)

func handle_state_transitions() -> void:
	if current_state == State.STUNNED:
		return
	
	if not dash_timer.is_stopped():
		change_state(State.DASHING)
		return
	
	if is_on_floor():
		has_wall_jumped = false
		can_wall_jump = true
		
		if abs(velocity.x) > 10:
			change_state(State.WALKING)
		elif big_jump_timer.time_left > 0:
			change_state(State.CHARGING_JUMP)
		else:
			change_state(State.IDLE)
	else:
		if is_on_wall() and velocity.y > 0:
			var wall_normal = get_wall_normal().x
			var input_direction = Input.get_axis("A_left", "D_right")
			if input_direction != 0 and sign(input_direction) != sign(wall_normal):
				change_state(State.WALL_SLIDING)
		elif current_state != State.WALL_JUMPING:
			change_state(State.JUMPING)

func handle_current_state() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	match current_state:
		State.IDLE, State.WALKING:
			handle_ground_movement(input_direction)
			handle_ground_actions()
		State.JUMPING, State.DOUBLE_JUMPING:
			handle_air_movement(input_direction)
			handle_air_actions()
		State.WALL_SLIDING:
			handle_wall_slide()
			handle_wall_actions()
		State.WALL_JUMPING:
			if wall_jump_control_timer.is_stopped():
				handle_air_movement(input_direction)
			handle_air_actions()
		State.DASHING:
			pass
		State.CHARGING_JUMP:
			handle_charge_jump()
		State.STUNNED:
			pass

func handle_ground_movement(input_direction: float) -> void:
	if input_direction:
		velocity.x = input_direction * character_data.speed
		if current_state == State.CHARGING_JUMP:
			cancel_big_jump_charge()
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed)

func handle_air_movement(input_direction: float) -> void:
	if input_direction:
		velocity.x = input_direction * character_data.speed
	else:
		velocity.x = move_toward(velocity.x, 0, character_data.speed * 0.1)

func handle_ground_actions() -> void:
	if current_state == State.STUNNED:
		return
		
	if Input.is_action_just_pressed("W_jump"):
		perform_jump()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()
	
	if Input.is_action_just_pressed("I_attack"):
		perform_attack()
	
	if Input.is_action_just_pressed("S_charge_jump") and velocity.x == 0:
		start_big_jump_charge()

func handle_air_actions() -> void:
	if Input.is_action_just_pressed("W_jump") and can_double_jump and current_state != State.WALL_JUMPING:
		perform_double_jump()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()
	
	if Input.is_action_just_pressed("I_attack"):
		perform_attack()

func handle_wall_actions() -> void:
	if Input.is_action_just_pressed("W_jump") and can_wall_jump:
		perform_wall_jump()
	
	if Input.is_action_just_pressed("J_dash"):
		attempt_dash()

func handle_wall_slide() -> void:
	velocity.y = min(velocity.y, gravity * character_data.wall_slide_gravity_multiplier)

func handle_charge_jump() -> void:
	if Input.is_action_just_released("S_charge_jump") and velocity.x != 0:
		cancel_big_jump_charge()

	if velocity.x != 0:
		cancel_big_jump_charge()
		print("Big jump cancelled - movement detected!")

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if current_state == State.WALL_SLIDING:
			velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
		elif Input.is_action_pressed("S_charge_jump") and velocity.y > 0:
			velocity.y += gravity * delta * character_data.landing_multiplier
		else:
			velocity.y += gravity * delta

func perform_jump() -> void:
	if big_jump_charged:
		velocity.y = character_data.jump_velocity * character_data.big_jump_multiplier
		big_jump_charged = false
		print("BIG JUMP EXECUTED! Force: ", character_data.jump_velocity * character_data.big_jump_multiplier)
	else:
		velocity.y = character_data.jump_velocity
		print("Jump!")
	change_state(State.JUMPING)

func perform_double_jump() -> void:
	velocity.y = character_data.jump_velocity * character_data.double_jump_multiplier
	can_double_jump = false
	reset_air_time()
	change_state(State.DOUBLE_JUMPING)
	print("Double jump!")

func perform_wall_jump() -> void:
	velocity.y = character_data.jump_velocity
	velocity.x = -get_wall_normal().x * character_data.wall_jump_force
	can_double_jump = not has_wall_jumped
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
	dash_timer.start()
	dash_cooldown_timer.start()
	change_state(State.DASHING)

func perform_attack() -> void:
	animation_player_2.play("Attack_1")
	hide_weapon = false
	hide_weapon_timer.stop()
	hide_weapon_timer.start()
	print("Attack!")

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
	if not is_on_floor() and not is_on_wall():
		air_time += delta
		if Input.is_action_pressed("S_charge_jump"):
			s_was_clicked = true
			effective_air_time += delta * character_data.landing_multiplier
		else:
			s_was_clicked = false
			effective_air_time += delta
	elif is_on_floor() and air_time > 0:
		check_stun_on_landing()
		reset_air_time()
	elif is_on_wall():
		reset_air_time()

func check_stun_on_landing() -> void:
	print("Total air time: ", air_time, "s")
	print("Effective air time: ", effective_air_time, "s")
	if s_was_clicked:
		animation_player_2.play("Attack_1")
		hide_weapon = false
		hide_weapon_timer.stop()
		hide_weapon_timer.start()
	if effective_air_time > character_data.stun_after_land_treshold:
		change_state(State.STUNNED)
		stun_timer.start()

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0

func handle_animations() -> void:
	match current_state:
		State.IDLE:
			animation_player.play("Idle")
		State.WALKING:
			animation_player.play("Walk")
			flip_body()
		State.JUMPING, State.DOUBLE_JUMPING, State.WALL_JUMPING:
			animation_player.play("Jump")
			flip_body()
		State.WALL_SLIDING:
			animation_player.play("Jump")
			flip_body()
		State.DASHING:
			animation_player.play("Dash")
		State.CHARGING_JUMP:
			animation_player.play("Big_jump_charge")
		State.STUNNED:
			if animation_player.current_animation != "Landing":
				animation_player.play("Landing")


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

func flip_body() -> void:
	if velocity.x != 0:
		body.scale.x = 1 if velocity.x < 0 else -1

func _on_hide_weapon_timer_timeout() -> void:
	hide_weapon = true

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
