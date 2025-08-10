extends CharacterBody2D
class_name CharacterManager

@export_category("Components")
@export var character_data: CharacterData
@export var body_node: BodyNode
@export var animation_player: AnimationPlayer
@export var camera_2d: Camera2D
@export var state_machine: CallableStateMachine

@export_category("Utils")
@export var ray_casts_handler: RayCastsHandler
@export var timers_handler: TimersHandler
@export var areas_handler: AreasHandler

@export_category("Controllers")
@export var movement_controller: MovementController
@export var jump_controller: JumpController
@export var combat_controller: CombatController
@export var stats_controller: StatsController

@export_category("UI")
@export var stamina_bar: ProgressBar
@export var health_bar: ProgressBar

@export_category("Debug")
@export var debug_helper: DebugHelper

var current_state = state_machine.State.IDLE
var previous_state = state_machine.State.IDLE

var death_animation_played: bool = false

var health_current: int:
	get:
		return stats_controller.get_health() if stats_controller else 0

var stamina_current: float:
	get:
		return stats_controller.get_stamina() if stats_controller else 0.0
	set(value):
		if stats_controller:
			var diff = value - stats_controller.get_stamina()
			if diff < 0:
				stats_controller.consume_stamina(-diff, false)
			else:
				stats_controller.restore_stamina(diff)

var stamina_regen_timer: float:
	get:
		return stats_controller.stamina_regen_timer if stats_controller else 0.0
	set(value):
		if stats_controller:
			stats_controller.stamina_regen_timer = value

var invulnerability_temp: bool:
	get:
		return stats_controller.invulnerability_temp if stats_controller else false
	set(value):
		if stats_controller:
			if value:
				stats_controller.activate_temporary_invulnerability()
			else:
				stats_controller.deactivate_temporary_invulnerability()

func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	
	setup_controllers()
	timers_handler.setup_timers()
	ray_casts_handler.setup_raycasts()
	setup_signals()
	combat_controller.set_weapon_visibility("hide")

func setup_controllers():
	if jump_controller:
		jump_controller.setup(self, state_machine)
	if combat_controller:
		combat_controller.setup(self, state_machine, animation_player, body_node, areas_handler, timers_handler)
	if movement_controller:
		movement_controller.setup(self, state_machine, character_data, body_node, animation_player, ray_casts_handler, timers_handler, jump_controller, combat_controller)
	if stats_controller:
		stats_controller.setup(self, character_data, state_machine, timers_handler, areas_handler, movement_controller, debug_helper)
		stats_controller.health_changed.connect(_on_health_changed)
		stats_controller.stamina_changed.connect(_on_stamina_changed)
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)
		state_machine.transition_to(state_machine.State.IDLE)

func _on_state_changed(old_state, new_state):
	exit_current_state()
	current_state = new_state
	previous_state = old_state
	enter_new_state(new_state)

func _process(delta: float) -> void:
	if stats_controller:
		stats_controller.process_stats(delta)
	if current_state != state_machine.State.DEATH:
		movement_controller.update_big_jump_stamina(delta)
		movement_controller.update_dash_attack_stamina(delta)
	update_ui()

func _physics_process(delta: float) -> void:
	movement_controller.process_physics(delta)
	
	if current_state == state_machine.State.KNOCKBACK or current_state == state_machine.State.DEATH:
		update_animations()
		move_and_slide()
		return
	
	movement_controller.update_state_transitions()
	process_current_state(delta)
	update_character_direction()
	update_animations()
	move_and_slide()

func setup_signals() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)

func transition_to_state(new_state) -> void:
	if current_state == new_state:
		return
	
	exit_current_state()
	
	previous_state = current_state
	current_state = new_state
	
	enter_new_state(new_state)

func exit_current_state() -> void:
	if current_state == state_machine.State.ATTACKING and current_state != state_machine.State.KNOCKBACK and current_state != state_machine.State.DASH_ATTACK:
		combat_controller.on_attack_state_exit()
	
	movement_controller.on_state_exit(current_state)
	if stats_controller:
		stats_controller.on_state_exit(current_state)

func enter_new_state(new_state) -> void:
	match new_state:
		state_machine.State.IDLE, state_machine.State.WALKING:
			jump_controller.reset_jump_state()
		state_machine.State.STUNNED:
			velocity.x = 0
			movement_controller.cancel_big_jump_charge()
		state_machine.State.JUMPING:
			if previous_state == state_machine.State.IDLE or previous_state == state_machine.State.WALKING:
				jump_controller.has_double_jump = true
				jump_controller.has_triple_jump = false
				jump_controller.jump_count = 1
		state_machine.State.DOUBLE_JUMPING:
			jump_controller.jump_count = 2
			jump_controller.has_triple_jump = true
			play_animation("Double_jump")
		state_machine.State.TRIPLE_JUMPING:
			jump_controller.jump_count = 3
			play_animation("Triple_jump")
		state_machine.State.ATTACKING:
			combat_controller.on_attack_state_enter()
		state_machine.State.DEATH:
			velocity.x = 0
			death_animation_played = false
	
	movement_controller.on_state_enter(new_state)
	if stats_controller:
		stats_controller.on_state_enter(new_state)

func process_current_state(delta) -> void:
	if current_state == state_machine.State.KNOCKBACK or current_state == state_machine.State.DEATH:
		return
		
	var input_direction = Input.get_axis("A_left", "D_right")
	
	movement_controller.process_state_movement(delta, input_direction)
	
	match current_state:
		state_machine.State.IDLE, state_machine.State.WALKING:
			process_ground_input()
		state_machine.State.JUMPING, state_machine.State.DOUBLE_JUMPING, state_machine.State.TRIPLE_JUMPING:
			process_air_input()
		state_machine.State.WALL_JUMPING:
			process_air_input()
		state_machine.State.STUNNED:
			pass

func process_ground_input() -> void:
	if current_state == state_machine.State.STUNNED:
		return
	
	movement_controller.process_big_jump_input()
	
	if Input.is_action_just_pressed("W_jump"):
		if movement_controller.big_jump_charged and Input.is_action_pressed("J_dash"):
			movement_controller.execute_directional_big_jump(Vector2(0, -1))
		else:
			movement_controller.execute_jump()
	
	if Input.is_action_just_pressed("J_dash") and velocity.x != 0:
		movement_controller.perform_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		if movement_controller.big_jump_charged and Input.is_action_pressed("J_dash"):
			movement_controller.execute_dash_attack()
		else:
			combat_controller.perform_attack()
	
	movement_controller.perform_charge_big_jump()

func process_air_input() -> void:
	if Input.is_action_just_pressed("W_jump"):
		movement_controller.perform_air_jump()
	
	movement_controller.process_big_jump_input()
	
	if Input.is_action_just_pressed("J_dash") and current_state != state_machine.State.ATTACKING:
		movement_controller.perform_dash()
	
	if Input.is_action_just_pressed("L_attack"):
		if movement_controller.big_jump_charged and Input.is_action_pressed("J_dash"):
			movement_controller.execute_dash_attack()
		else:
			combat_controller.perform_air_attack()
	
	if Input.is_action_just_pressed("S_charge_jump"):
		movement_controller.perform_big_attack()

func update_character_direction() -> void:
	if current_state == state_machine.State.DEATH:
		return
		
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if current_state == state_machine.State.WALL_SLIDING:
		if ray_casts_handler.left_wall_ray.is_colliding():
			body_node.scale.x = 1
		elif ray_casts_handler.right_wall_ray.is_colliding():
			body_node.scale.x = -1
	elif input_direction != 0 and current_state != state_machine.State.DASH_ATTACK:
		body_node.scale.x = -sign(input_direction)

func apply_knockback(force: Vector2) -> void:
	movement_controller.apply_knockback(force)

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if stats_controller:
		stats_controller.take_damage(amount, attacker_position)

func update_animations() -> void:
	match current_state:
		state_machine.State.IDLE:
			if movement_controller.big_jump_charged and Input.is_action_pressed("J_dash"):
				play_animation("Big_jump_charge")
			else:
				play_animation("Idle")
		state_machine.State.WALKING:
			play_animation("Walk")
		state_machine.State.JUMPING, state_machine.State.WALL_JUMPING:
			if not animation_player.current_animation.begins_with("Attack_air"):
				play_animation("Jump")
		state_machine.State.BIG_JUMPING:
			play_animation("Dash")
		state_machine.State.BIG_ATTACK:
			if not character_data.can_big_attack:
				return
			if movement_controller.is_high_big_attack and animation_player.current_animation != "Big_attack":
				play_animation("Big_attack_prepare")
				combat_controller.set_weapon_visibility("both")
		state_machine.State.BIG_ATTACK_LANDING:
			if animation_player.current_animation != "Big_attack_landing":
				play_animation("Big_attack_landing")
		state_machine.State.WALL_SLIDING:
			if Input.is_action_pressed("J_dash"):
				play_animation("Big_jump_wall_charge")
			else:
				play_animation("Sliding_wall")
		state_machine.State.DASHING:
			play_animation("Dash")
		state_machine.State.DASH_ATTACK:
			play_animation("Dash_attack")
			combat_controller.set_weapon_visibility("both")
		state_machine.State.CHARGING_JUMP:
			play_animation("Big_jump_charge")
		state_machine.State.STUNNED:
			pass
		state_machine.State.KNOCKBACK:
			play_animation("Jump")
		state_machine.State.DOUBLE_JUMPING, state_machine.State.TRIPLE_JUMPING:
			pass
		state_machine.State.ATTACKING:
			combat_controller.update_attack_animations()
		state_machine.State.DEATH:
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
	if stats_controller:
		stamina_bar.value = stats_controller.get_stamina()
		stamina_bar.max_value = stats_controller.get_max_stamina()
		health_bar.value = stats_controller.get_health()
		health_bar.max_value = stats_controller.get_max_health()

func _on_health_changed(_new_health: int) -> void:
	pass

func _on_stamina_changed(_new_stamina: float) -> void:
	pass

func _on_big_jump_timer_timeout() -> void:
	movement_controller.on_big_jump_timer_timeout()

func _on_big_jump_cooldown_timer_timeout() -> void:
	movement_controller.on_big_jump_cooldown_timer_timeout()

func _on_stun_timer_timeout() -> void:
	state_machine.transition_to(state_machine.State.IDLE)

func _on_dash_cooldown_timer_timeout() -> void:
	movement_controller.on_dash_cooldown_timer_timeout()

func _on_invulnerability_timer_timeout() -> void:
	if stats_controller:
		stats_controller.deactivate_temporary_invulnerability()

func _on_animation_finished(anim_name: String) -> void:
	if current_state == state_machine.State.ATTACKING:
		combat_controller.handle_attack_animation_finished(anim_name)
	
	elif current_state == state_machine.State.DOUBLE_JUMPING and anim_name == "Double_jump":
		play_animation("Jump")
	elif current_state == state_machine.State.TRIPLE_JUMPING and anim_name == "Triple_jump":
		play_animation("Jump")
	elif current_state == state_machine.State.DASH_ATTACK and anim_name == "Dash_attack":
		movement_controller.end_dash_attack()
	elif current_state == state_machine.State.BIG_ATTACK and anim_name == "Big_attack_prepare":
		play_animation("Big_attack")
	elif anim_name == "Big_attack" and (current_state == state_machine.State.BIG_ATTACK_LANDING or is_on_floor()):
		if not animation_player.is_playing() or animation_player.current_animation != "Big_attack_landing":
			play_animation("Big_attack_landing")
	elif anim_name == "Big_attack_landing":
		if movement_controller.effective_air_time > character_data.stun_after_land_treshold:
			state_machine.transition_to(state_machine.State.STUNNED)
			timers_handler.stun_timer.start()
		else:
			state_machine.transition_to(state_machine.State.IDLE)
