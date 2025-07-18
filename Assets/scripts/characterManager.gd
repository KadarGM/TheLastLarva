extends CharacterBody2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_player_2: AnimationPlayer = $AnimationPlayer2

@onready var body: Node2D = $Body

@onready var big_jump_timer: Timer = $Timers/BigJumpTimer
@onready var in_air_timer: Timer = $Timers/InAirTimer
@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var dash_timer: Timer = $Timers/DashTimer

@onready var sword_f: Sprite2D = $Body/body/armF_1/handF_1/swordF
@onready var sword_b: Sprite2D = $Body/body/armB_1/handB_1/swordB
@onready var sword_body: Sprite2D = $Body/body/swordBody

var speed: float = 600.0
var jump_velocity: float = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var big_jump_charge_time: float = 3.0
var is_charging_big_jump: bool = false
var big_jump_charged: bool = false
var big_jump_multiplier: float = 1.5

var in_the_air_charging: bool = false
var in_the_air: bool = false
var falling_treshold: float = 3.0
var was_on_floor: bool = true

var landing_multiplier: float = 10.0

var hide_weapon_time: float = 2.0
var can_attack: bool = true
var hide_weapon: bool = true

var dash_speed: float = 1200.0
var dash_duration: float = 0.2
var can_dash: bool = true

var can_double_jump: bool = true
var double_jump_multiplier: float = 0.8

var fall_damage_threshold: float = 15.0
var fall_damage_multiplier: float = 2.0
var fall_damage_lethal: float = 40.0
var fall_time: float = 0.0
var max_health: float = 100.0
var current_health: float = 100.0

var wall_slide_gravity_multiplier: float = .8
var is_wall_sliding: bool = false
var wall_jump_force: float = 800.0

func _ready() -> void:
	init_timers()

func init_timers() -> void:
	big_jump_timer.wait_time = big_jump_charge_time
	big_jump_timer.one_shot = true
	big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
	
	in_air_timer.wait_time = falling_treshold
	in_air_timer.one_shot = true
	in_air_timer.timeout.connect(_on_in_air_timer_timeout)
	
	hide_weapon_timer.wait_time = hide_weapon_time
	hide_weapon_timer.one_shot = true
	hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)
	
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_on_dash_timer_timeout)

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jump()
	handle_movement()
	handle_dash()
	handle_wall_mechanics(delta)
	check_fall_damage(delta)
	
	if velocity.x:
		flip_body()
		if is_on_floor():
			animation_player.play("Walk")
		else:
			animation_player.play("Jump")
	else:
		if is_on_floor() and Input.is_action_pressed("S_charge_jump"):
			animation_player.play("Big_jump")
			animation_player.speed_scale += (big_jump_timer.wait_time - big_jump_timer.time_left)/100
			if big_jump_timer.time_left == 0:
				animation_player.speed_scale = 1
				animation_player.play("Idle")
		elif is_on_floor():
			animation_player.play("Idle")
		else:
			animation_player.play("Jump")
	
	if Input.is_action_just_pressed("I_attack"):
		animation_player_2.play("Attack_1")
		hide_weapon = false
		hide_weapon_timer.stop()
		hide_weapon_timer.start()
	
	hiding_weapon()
	handle_big_jump()
	handle_falling()
	move_and_slide()

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y += gravity * delta * wall_slide_gravity_multiplier
			velocity.y = min(velocity.y, gravity * wall_slide_gravity_multiplier)
		elif Input.is_action_pressed("S_charge_jump"):
			velocity.y += gravity * delta * landing_multiplier
		else:
			velocity.y += gravity * delta

func handle_jump() -> void:
	if Input.is_action_just_pressed("W_jump"):
		if is_on_floor() and not is_charging_big_jump:
			if big_jump_charged:
				velocity.y = jump_velocity * big_jump_multiplier
				big_jump_charged = false
				can_double_jump = true
				print("BIG JUMP EXECUTED! Force: ", jump_velocity * big_jump_multiplier)
			else:
				velocity.y = jump_velocity
				can_double_jump = true
				print("Normal jump: ", jump_velocity)
		elif is_on_wall() and not is_on_floor():
			velocity.y = jump_velocity
			velocity.x = -get_wall_normal().x * wall_jump_force
			can_double_jump = true
		elif not is_on_floor() and can_double_jump:
			velocity.y = jump_velocity * double_jump_multiplier
			can_double_jump = false
			print("Double jump!")
	
	if is_on_floor():
		can_double_jump = true

func handle_movement() -> void:
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if not is_dashing():
		if input_direction:
			velocity.x = input_direction * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)

func handle_dash() -> void:
	if Input.is_action_just_pressed("J_dash") and can_dash:
		var dash_direction = Input.get_axis("A_left", "D_right")
		if dash_direction != 0:
			velocity.x = dash_direction * dash_speed
			velocity.y = 0
			can_dash = false
			dash_timer.start()
			print("Dash!")
	
	if is_on_floor() or is_on_wall():
		can_dash = true

func handle_wall_mechanics(_delta: float) -> void:
	if is_on_wall() and not is_on_floor():
		var wall_direction = get_wall_normal().x
		var input_direction = Input.get_axis("A_left", "D_right")
		
		if input_direction != 0 and sign(input_direction) != sign(wall_direction):
			is_wall_sliding = true
		else:
			is_wall_sliding = false
	else:
		is_wall_sliding = false

func check_fall_damage(delta: float) -> void:
	if not is_on_floor() and not is_on_wall():
		if not is_dashing():
			fall_time += delta * 10
	else:
		if is_on_floor() and fall_time > fall_damage_threshold:
			var damage = fall_damage_multiplier * (fall_time - fall_damage_threshold)
			current_health -= damage
			print("Fall damage: ", damage, " Health: ", current_health)
			
			if fall_time > fall_damage_lethal:
				current_health = 0
				print("Lethal fall!")
			
			if current_health <= 0:
				current_health = max_health
				print("Respawn!")
		fall_time = 0

func is_dashing() -> bool:
	return not dash_timer.is_stopped()

func flip_body() -> void:
	body.scale.x = 1 if velocity.x < 0 else -1

func handle_big_jump() -> void:
	if Input.is_action_just_pressed("S_charge_jump") and is_on_floor() and not big_jump_charged and not is_charging_big_jump:
		is_charging_big_jump = true
		big_jump_timer.start()
		print("BIG JUMP CHARGING STARTED - Timer: ", big_jump_timer.wait_time, "s")
	
	if Input.is_action_just_released("S_charge_jump") and is_charging_big_jump:
		is_charging_big_jump = false
		big_jump_charged = false
		big_jump_timer.stop()
		print("BIG JUMP CANCELLED - Time left: ", big_jump_timer.time_left, "s")
	
	if is_charging_big_jump:
		print("Charging... Time left: ", big_jump_timer.time_left, "s")

func handle_falling() -> void:
	if not is_on_floor() and was_on_floor:
		in_the_air_charging = true
		in_air_timer.start()
		print("LEFT GROUND - Starting air timer: ", in_air_timer.wait_time, "s")
	
	if is_on_floor() and not was_on_floor:
		in_the_air_charging = false
		in_the_air = false
		in_air_timer.stop()
		print("LANDED - Resetting air state")
	
	if in_the_air_charging:
		print("In air... Time left: ", in_air_timer.time_left, "s")
	
	was_on_floor = is_on_floor()

func _on_hide_weapon_timer_timeout() -> void:
	hide_weapon = true

func _on_big_jump_timer_timeout() -> void:
	if is_charging_big_jump:
		big_jump_charged = true
		is_charging_big_jump = false
		print("BIG JUMP FULLY CHARGED!")

func _on_in_air_timer_timeout() -> void:
	if in_the_air_charging:
		in_the_air = true
		in_the_air_charging = false
		print("FALLING STATE ACTIVATED!")

func _on_dash_timer_timeout() -> void:
	pass

func hiding_weapon() -> void:
	if hide_weapon == true:
		sword_b.visible = false
		sword_body.visible = true
	else:
		sword_b.visible = true
		sword_body.visible = false
