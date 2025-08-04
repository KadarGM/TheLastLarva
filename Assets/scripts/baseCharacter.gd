extends CharacterBody2D
class_name BaseCharacter

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
	DASH_ATTACK,
	KNOCKBACK,
	DEATH,
	CHASING
}

@export var character_data: CharacterData
@export var capabilities: CharacterCapabilities

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body: Node2D = $Body

@onready var attack_area: Area2D = $Body/AttackArea
@onready var damage_area: Area2D = $Areas/DamageArea

@onready var hide_weapon_timer: Timer = $Timers/HideWeaponTimer
@onready var dash_timer: Timer = $Timers/DashTimer
@onready var stun_timer: Timer = $Timers/StunTimer
@onready var dash_cooldown_timer: Timer = $Timers/DashCooldownTimer
@onready var wall_jump_control_timer: Timer = $Timers/WallJumpControlTimer
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

var current_state: State = State.IDLE
var previous_state: State = State.IDLE

var health_current: int
var stamina_current: float
var stamina_regen_timer: float = 0.0

var jump_count: int = 0
var can_double_jump: bool = true
var can_triple_jump: bool = false
var is_jump_held: bool = false

var can_dash: bool = true
var can_wall_jump: bool = true
var has_wall_jumped: bool = false
var was_on_wall: bool = false

var count_of_attack: int = 0
var damage_applied_this_attack: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var invulnerability: bool = false
var death_animation_played: bool = false

var movement_direction: int = 1

func _ready() -> void:
	if not character_data:
		push_error("Character needs CharacterData resource!")
		return
	if not capabilities:
		capabilities = CharacterCapabilities.new()
		
	health_current = character_data.health_max
	stamina_current = character_data.stamina_max
	
	call_deferred("init_timers")
	call_deferred("setup_raycasts")
	call_deferred("connect_signals")
	call_deferred("update_weapon_visibility", "hide")
	call_deferred("initialize_character")

func initialize_character() -> void:
	pass

func connect_signals() -> void:
	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	if damage_area:
		damage_area.body_entered.connect(_on_damage_area_body_entered)

func _process(delta: float) -> void:
	check_death()
	if current_state != State.DEATH:
		handle_stamina_regeneration(delta)
	process_character(delta)

func process_character(_delta: float) -> void:
	pass

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
	handle_current_state(delta)
	handle_animations()
	physics_process_character(delta)
	move_and_slide()

func physics_process_character(_delta: float) -> void:
	pass

func setup_raycasts() -> void:
	if ground_check_ray:
		ground_check_ray.target_position = Vector2(0, character_data.ground_check_ray_length)
		ground_check_ray.enabled = true
	if ground_check_ray_2:
		ground_check_ray_2.target_position = Vector2(0, character_data.ground_check_ray_length)
		ground_check_ray_2.enabled = true
	if ground_check_ray_3:
		ground_check_ray_3.target_position = Vector2(0, character_data.ground_check_ray_length)
		ground_check_ray_3.enabled = true
	
	if left_wall_ray:
		left_wall_ray.target_position = Vector2(-character_data.wall_ray_cast_length, 0)
		left_wall_ray.enabled = true
	if right_wall_ray:
		right_wall_ray.target_position = Vector2(character_data.wall_ray_cast_length, 0)
		right_wall_ray.enabled = true

func init_timers() -> void:
	if hide_weapon_timer:
		hide_weapon_timer.wait_time = character_data.hide_weapon_time
		hide_weapon_timer.one_shot = true
		hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)
	
	if dash_timer and capabilities.can_dash:
		dash_timer.wait_time = character_data.dash_duration
		dash_timer.one_shot = true
	
	if dash_cooldown_timer and capabilities.can_dash:
		dash_cooldown_timer.wait_time = character_data.dash_cooldown_time
		dash_cooldown_timer.one_shot = true
		dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	
	if stun_timer:
		stun_timer.wait_time = character_data.stun_time
		stun_timer.one_shot = true
		stun_timer.timeout.connect(_on_stun_timer_timeout)
	
	if wall_jump_control_timer and capabilities.can_wall_jump:
		wall_jump_control_timer.wait_time = character_data.wall_jump_control_delay
		wall_jump_control_timer.one_shot = true
	
	if attack_cooldown_timer:
		attack_cooldown_timer.wait_time = character_data.attack_cooldown
		attack_cooldown_timer.one_shot = true
		attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	
	if damage_timer:
		damage_timer.wait_time = character_data.damage_delay
		damage_timer.one_shot = true
		damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	if invulnerability_timer:
		invulnerability_timer.wait_time = character_data.invulnerability_after_damage
		invulnerability_timer.one_shot = true
		invulnerability_timer.timeout.connect(_on_invulnerability_timer_timeout)

func check_death() -> void:
	if health_current <= 0 and current_state != State.DEATH:
		change_state(State.DEATH)

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return
	
	exit_state(current_state)
	
	previous_state = current_state
	current_state = new_state
	
	enter_state(new_state)

func exit_state(state: State) -> void:
	match state:
		State.DASHING, State.BIG_ATTACK, State.DASH_ATTACK:
			invulnerability = false

func enter_state(state: State) -> void:
	match state:
		State.IDLE, State.WALKING:
			jump_count = 0
		State.STUNNED:
			velocity.x = 0
		State.WALL_JUMPING:
			if wall_jump_control_timer:
				wall_jump_control_timer.start()
			has_wall_jumped = true
			jump_count = 0
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
			invulnerability = true
		State.ATTACKING:
			damage_applied_this_attack = false
			if damage_timer:
				damage_timer.start()
		State.KNOCKBACK:
			pass
		State.DEATH:
			if damage_area:
				damage_area.set_deferred("monitorable", false)
			velocity.x = 0
			death_animation_played = false

func handle_state_transitions() -> void:
	pass

func handle_current_state(_delta: float) -> void:
	pass

func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if current_state == State.WALL_SLIDING and capabilities.can_wall_slide:
			velocity.y += gravity * delta * character_data.wall_slide_gravity_multiplier
		else:
			velocity.y += gravity * delta

func handle_knockback(delta: float) -> void:
	if knockback_timer > 0:
		knockback_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, character_data.knockback_friction * delta)
		
		if knockback_timer <= 0 or knockback_velocity.length() < 10:
			knockback_velocity = Vector2.ZERO
			if self is EnemyCharacter:
				if get("player_in_detection_zone"):
					change_state(State.CHASING)
				else:
					change_state(State.WALKING)
			else:
				change_state(State.IDLE)

func handle_stamina_regeneration(delta: float) -> void:
	if stamina_current >= character_data.stamina_max:
		return
	
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
		return
	
	stamina_current += character_data.stamina_regen_rate * delta
	stamina_current = min(stamina_current, character_data.stamina_max)

func perform_jump() -> void:
	if not capabilities.can_jump:
		return
		
	velocity.y = character_data.jump_velocity
	is_jump_held = true
	change_state(State.JUMPING)

func perform_double_jump() -> void:
	if not capabilities.can_double_jump:
		return
		
	velocity.y = character_data.jump_velocity * character_data.double_jump_multiplier
	can_double_jump = false
	change_state(State.DOUBLE_JUMPING)
	if animation_player:
		animation_player.play("Double_jump")
		animation_player.queue("Jump")

func perform_triple_jump() -> void:
	if not capabilities.can_triple_jump:
		return
		
	if stamina_current >= character_data.triple_jump_stamina_cost:
		stamina_current -= character_data.triple_jump_stamina_cost
		stamina_regen_timer = character_data.stamina_regen_delay
		
		velocity.y = character_data.jump_velocity * character_data.triple_jump_multiplier
		can_triple_jump = false
		change_state(State.TRIPLE_JUMPING)
		if animation_player:
			animation_player.play("Triple_jump")
			animation_player.queue("Jump")

func perform_attack() -> void:
	if not capabilities.can_attack:
		return
		
	if not attack_cooldown_timer or not attack_cooldown_timer.is_stopped():
		return
	
	if stamina_current < character_data.attack_stamina_cost:
		return
	
	stamina_current -= character_data.attack_stamina_cost
	stamina_regen_timer = character_data.stamina_regen_delay
	
	change_state(State.ATTACKING)
	
	var max_count_of_attack = 3
	if count_of_attack < max_count_of_attack:
		count_of_attack += 1
	else:
		count_of_attack = 1
	
	if hide_weapon_timer:
		hide_weapon_timer.stop()
		hide_weapon_timer.start()
	if attack_cooldown_timer:
		attack_cooldown_timer.start()

func take_damage(amount: int) -> void:
	if current_state == State.DEATH:
		return
	
	if invulnerability:
		return
	
	health_current -= amount
	health_current = max(0, health_current)
	
	stamina_current -= character_data.damage_stamina_cost
	stamina_current = max(0, stamina_current)
	stamina_regen_timer = character_data.stamina_regen_delay
	
	invulnerability = true
	if invulnerability_timer:
		invulnerability_timer.start()
	
	if health_current <= 0:
		die()

func apply_knockback(force: Vector2) -> void:
	if current_state == State.DEATH or current_state == State.KNOCKBACK:
		return
	
	if current_state == State.BIG_ATTACK or current_state == State.BIG_ATTACK_LANDING:
		return
	
	knockback_velocity = Vector2(force.x * character_data.knockback_force_horizontal_multiplier, force.y)
	knockback_timer = character_data.knockback_duration
	
	change_state(State.KNOCKBACK)

func die() -> void:
	change_state(State.DEATH)

func get_damage() -> float:
	return character_data.attack_1_dmg

func handle_animations() -> void:
	if not animation_player:
		return
		
	match current_state:
		State.IDLE:
			animation_player.play("Idle")
		State.WALKING, State.CHASING:
			animation_player.play("Walk")
		State.JUMPING, State.WALL_JUMPING:
			animation_player.play("Jump")
		State.WALL_SLIDING:
			animation_player.play("Sliding_wall")
		State.DASHING:
			animation_player.play("Dash")
		State.STUNNED:
			pass
		State.KNOCKBACK:
			animation_player.play("Jump")
		State.DOUBLE_JUMPING, State.TRIPLE_JUMPING:
			pass
		State.ATTACKING:
			handle_attack_animation()
		State.DEATH:
			if not death_animation_played:
				animation_player.play("Death")

func handle_attack_animation() -> void:
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

func apply_damage_to_entities() -> void:
	if not attack_area:
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
	
	var base_knockback_force = character_data.knockback_force
	if count_of_attack == 3:
		base_knockback_force *= character_data.knockback_force_multiplier
	
	var attack_dir: float = -body.scale.x if body else 1.0
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		
		var knockback_force = Vector2(
			attack_dir * base_knockback_force,
			character_data.jump_velocity * character_data.knockback_vertical_multiplier
		)
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		if entity.has_method("apply_knockback"):
			entity.apply_knockback(knockback_force)

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

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true

func _on_stun_timer_timeout() -> void:
	change_state(State.IDLE)

func _on_attack_area_body_entered(_body: Node2D) -> void:
	pass

func _on_attack_area_body_exited(_body: Node2D) -> void:
	pass

func _on_damage_area_body_entered(entered_body: Node2D) -> void:
	if invulnerability:
		return
	
	if entered_body == self:
		return
	
	if self.is_in_group("Enemy") and entered_body.is_in_group("Player"):
		return
	
	if self.is_in_group("Player") and entered_body.is_in_group("Enemy"):
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

func _on_animation_finished(anim_name: String) -> void:
	if current_state == State.ATTACKING:
		if anim_name.begins_with("Attack_ground") or anim_name.begins_with("Attack_air"):
			if is_on_floor():
				change_state(State.IDLE)
			else:
				change_state(State.JUMPING)
	elif anim_name == "Death":
		death_animation_played = true
		queue_free()
