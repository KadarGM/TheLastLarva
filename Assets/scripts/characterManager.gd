extends CharacterBody2D

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

@export var characterData: CharacterData

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var stamina_regen_timer: float = 0.0

func _ready() -> void:
	if not characterData:
		characterData = CharacterData.new()
	init_timers()

func init_timers() -> void:
	big_jump_timer.wait_time = characterData.big_jump_charge_time
	big_jump_timer.one_shot = true
	big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
	
	hide_weapon_timer.wait_time = characterData.hide_weapon_time
	hide_weapon_timer.one_shot = true
	hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)
	
	dash_timer.wait_time = characterData.dash_duration
	dash_timer.one_shot = true
	
	dash_cooldown_timer.wait_time = characterData.dash_cooldown_time
	dash_cooldown_timer.one_shot = true
	dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	
	stun_timer.wait_time = characterData.stun_time
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	
	wall_jump_control_timer.wait_time = characterData.wall_jump_control_delay
	wall_jump_control_timer.one_shot = true
	wall_jump_control_timer.timeout.connect(_on_wall_jump_control_timer_timeout)

func _process(delta: float) -> void:
	handle_stamina(delta)
	handle_stamina_bar()

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	if not characterData.is_stunned:
		handle_jump()
		handle_movement()
		handle_dash()
	handle_wall_mechanics(delta)
	handle_air_time(delta)

	
	if is_dashing():
		animation_player.play("Dash")
	elif velocity.x:
		flip_body()
		if is_on_floor():
			animation_player.play("Walk")
			animation_player.speed_scale = 1
		else:
			animation_player.play("Jump")
			animation_player.speed_scale = 1 + (characterData.air_time * 10)
		if characterData.is_stunned:
			animation_player.play("Landing")
	else:
		if is_on_floor() and Input.is_action_pressed("S_charge_jump") and not characterData.is_stunned:
			animation_player.play("Big_jump_charge")
			animation_player.speed_scale += (big_jump_timer.wait_time - big_jump_timer.time_left)/100
			if big_jump_timer.time_left == 0:
				animation_player.speed_scale = 1
				animation_player.play("Idle")
		elif is_on_floor():
			animation_player.play("Idle")
			animation_player.speed_scale = 1
		else:
			animation_player.play("Jump")
			animation_player.speed_scale = 1 + (characterData.air_time * 5)
	
	if Input.is_action_just_pressed("I_attack") and not characterData.is_stunned:
		animation_player_2.play("Attack_1")
		characterData.hide_weapon = false
		hide_weapon_timer.stop()
		hide_weapon_timer.start()
	
	hiding_weapon()
	handle_big_jump()
	move_and_slide()

func handle_stamina(delta):
	if characterData.stamina_current < characterData.stamina_max:
		if stamina_regen_timer > 0:
			stamina_regen_timer -= delta
		else:
			characterData.stamina_current += characterData.stamina_cost * characterData.stamina_regen_rate * delta
			if characterData.stamina_current > characterData.stamina_max:
				characterData.stamina_current = characterData.stamina_max

func handle_stamina_bar():
	stamina_bar.value = characterData.stamina_current
	stamina_bar.max_value = characterData.stamina_max

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if characterData.is_wall_sliding:
			velocity.y += gravity * delta * characterData.wall_slide_gravity_multiplier
			velocity.y = min(velocity.y, gravity * characterData.wall_slide_gravity_multiplier)
		elif Input.is_action_pressed("S_charge_jump") and velocity.y > 0:
			velocity.y += gravity * delta * characterData.landing_multiplier
		else:
			velocity.y += gravity * delta

func handle_jump() -> void:
	if Input.is_action_just_pressed("W_jump"):
		if is_on_floor() and not characterData.is_charging_big_jump:
			if characterData.big_jump_charged:
				velocity.y = characterData.jump_velocity * characterData.big_jump_multiplier
				characterData.big_jump_charged = false
				characterData.can_double_jump = true
				characterData.used_wall_jump_combo = false
				print("BIG JUMP EXECUTED! Force: ", characterData.jump_velocity * characterData.big_jump_multiplier)
			else:
				velocity.y = characterData.jump_velocity
				characterData.can_double_jump = true
				characterData.used_wall_jump_combo = false
				print("Normal jump: ", characterData.jump_velocity)
		elif is_on_wall() and not is_on_floor() and characterData.can_wall_jump:
			velocity.y = characterData.jump_velocity
			velocity.x = -get_wall_normal().x * characterData.wall_jump_force
			characterData.can_wall_jump = false
			characterData.is_wall_jumping = true
			wall_jump_control_timer.start()
			characterData.air_time = 0
			characterData.effective_air_time = 0
			if not characterData.used_wall_jump_combo:
				characterData.can_double_jump = true
			else:
				characterData.can_double_jump = false
		elif not is_on_floor() and characterData.can_double_jump and not is_on_wall():
			velocity.y = characterData.jump_velocity * characterData.double_jump_multiplier
			characterData.can_double_jump = false
			characterData.air_time = 0
			characterData.effective_air_time = 0
			if characterData.was_on_floor == false:
				characterData.used_wall_jump_combo = true
			print("Double jump!")
	
	if is_on_floor():
		characterData.can_double_jump = true
		characterData.used_wall_jump_combo = false
		characterData.is_wall_jumping = false

func handle_movement() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if not is_dashing() and not characterData.is_wall_jumping:
		if input_direction:
			velocity.x = input_direction * characterData.speed
			if characterData.is_charging_big_jump:
				characterData.is_charging_big_jump = false
				characterData.big_jump_charged = false
				big_jump_timer.stop()
				print("BIG JUMP CANCELLED - Movement detected")
		else:
			velocity.x = move_toward(velocity.x, 0, characterData.speed)

func handle_dash() -> void:
	if Input.is_action_just_pressed("J_dash") and characterData.can_dash and characterData.stamina_current >= characterData.stamina_cost:
		var dash_direction = Input.get_axis("A_left", "D_right")
		if dash_direction != 0:
			velocity.x = dash_direction * characterData.dash_speed
			velocity.y = 0
			characterData.can_dash = false
			characterData.stamina_current -= characterData.stamina_cost
			stamina_regen_timer = characterData.stamina_regen_delay
			dash_timer.start()
			dash_cooldown_timer.start()
			print("Dash! Stamina: ", characterData.stamina_current)

func handle_wall_mechanics(_delta: float) -> void:
	if is_on_wall() and not is_on_floor():
		var wall_direction = get_wall_normal().x
		var input_direction = Input.get_axis("A_left", "D_right")
		
		if input_direction != 0 and sign(input_direction) != sign(wall_direction):
			characterData.is_wall_sliding = true
			characterData.can_wall_jump = true
		else:
			characterData.is_wall_sliding = false
			characterData.can_wall_jump = false
	else:
		characterData.is_wall_sliding = false
		if not is_on_wall():
			characterData.can_wall_jump = true

func handle_air_time(delta: float) -> void:
	if not is_on_floor() and not is_on_wall():
		characterData.air_time += delta
		if Input.is_action_pressed("S_charge_jump"):
			characterData.effective_air_time += delta * characterData.landing_multiplier
		else:
			characterData.effective_air_time += delta
	else:
		if characterData.air_time > 0 and is_on_floor():
			print("Total air time: ", characterData.air_time, "s")
			print("Effective air time: ", characterData.effective_air_time, "s")
			if characterData.effective_air_time > characterData.stun_after_land_treshold:
				characterData.is_stunned = true
				stun_timer.start()
				velocity.x = 0
				print("STUNNED for ", characterData.stun_time, "s!")
			characterData.air_time = 0
			characterData.effective_air_time = 0
		elif is_on_wall():
			characterData.air_time = 0
			characterData.effective_air_time = 0
	
	characterData.was_on_floor = is_on_floor()

func is_dashing() -> bool:
	return not dash_timer.is_stopped()

func flip_body() -> void:
	body.scale.x = 1 if velocity.x < 0 else -1

func handle_big_jump() -> void:
	if Input.is_action_just_pressed("S_charge_jump") and is_on_floor() and not characterData.big_jump_charged and not characterData.is_charging_big_jump and not characterData.is_stunned:
		characterData.is_charging_big_jump = true
		big_jump_timer.start()
		print("BIG JUMP CHARGING STARTED - Timer: ", characterData.big_jump_charge_time, "s")
	
	if Input.is_action_just_released("S_charge_jump") and characterData.is_charging_big_jump:
		characterData.is_charging_big_jump = false
		characterData.big_jump_charged = false
		big_jump_timer.stop()
		print("BIG JUMP CANCELLED - Time left: ", big_jump_timer.time_left, "s")
	
	if characterData.is_charging_big_jump:
		print("Charging... Time left: ", big_jump_timer.time_left, "s")

func _on_hide_weapon_timer_timeout() -> void:
	characterData.hide_weapon = true

func _on_big_jump_timer_timeout() -> void:
	if characterData.is_charging_big_jump:
		characterData.big_jump_charged = true
		characterData.is_charging_big_jump = false
		print("BIG JUMP FULLY CHARGED!")

func _on_stun_timer_timeout() -> void:
	characterData.is_stunned = false
	print("Stun ended!")

func _on_dash_cooldown_timer_timeout() -> void:
	characterData.can_dash = true
	print("Dash ready!")

func _on_wall_jump_control_timer_timeout() -> void:
	characterData.is_wall_jumping = false

func hiding_weapon() -> void:
	if characterData.hide_weapon == true:
		sword_f.visible = false
		sword_b.visible = false
		sword_body_2.visible = true
		sword_body.visible = true
	else:
		sword_f.visible = true
		sword_b.visible = true
		sword_body_2.visible = false
		sword_body.visible = false
