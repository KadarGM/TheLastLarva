extends CharacterBody2D
class_name CharacterManager

@export_category("Components")
@export var character_data: CharacterData
@export var body_node: Node2D
@export var animation_player: AnimationPlayer
@export var state_machine: StateMachine
@export var controller: BaseController

@export_category("Handlers")
@export var ray_casts_handler: RayCastsHandler
@export var timers_handler: TimersHandler
@export var areas_handler: AreasHandler
@export var stats_controller: StatsController

@export_category("UI")
@export var stamina_bar: ProgressBar
@export var health_bar: ProgressBar

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var dash_count: int = 0
var jump_count: int = 0
var attack_count: int = 0
var has_double_jump: bool = false
var has_triple_jump: bool = false
var can_wall_jump: bool = false
var can_dash: bool = true
var can_big_jump: bool = true
var is_double_jump_held: bool = false
var is_triple_jump_held: bool = false

var big_jump_charged: bool = false
var big_jump_direction: Vector2 = Vector2.ZERO
var big_attack_pending: bool = false
var is_high_big_attack: bool = false

var air_time: float = 0.0
var effective_air_time: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var dash_attack_damaged_entities: Array = []
var death_animation_played: bool = false
var previous_state: String = ""

var count_of_attack: int = 0
var velocity_before_attack: float = 0.0
var pending_knockback_force: Vector2 = Vector2.ZERO
var damage_applied_this_attack: bool = false

var was_on_wall: bool = false
var invulnerability_temp: bool = false
var stamina_current: float = 0.0
var stamina_regen_timer: float = 0.0

var current_input: ControllerInput = ControllerInput.new()

var was_hit_by_damage: bool = false

func _ready() -> void:
	if not character_data:
		character_data = CharacterData.new()
	
	stamina_current = character_data.stamina_max
	
	if timers_handler:
		timers_handler.setup_timers()
	
	setup_signals()
	setup_stats_controller()
	set_weapon_visibility("hide")
	
	if not controller:
		for child in get_children():
			if child is BaseController:
				controller = child
				break
	
	if controller:
		controller.setup(self)

func setup_signals() -> void:
	if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	if state_machine and not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)
	if areas_handler and areas_handler.attack_area and not areas_handler.attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		areas_handler.attack_area.body_entered.connect(_on_attack_area_body_entered)
	if timers_handler and timers_handler.damage_timer and not timers_handler.damage_timer.timeout.is_connected(_on_damage_timer_timeout):
		timers_handler.damage_timer.timeout.connect(_on_damage_timer_timeout)

func setup_stats_controller() -> void:
	if stats_controller:
		stats_controller.setup(self, character_data, timers_handler, areas_handler, null)
		if not stats_controller.health_changed.is_connected(_on_health_changed):
			stats_controller.health_changed.connect(_on_health_changed)
		if not stats_controller.stamina_changed.is_connected(_on_stamina_changed):
			stats_controller.stamina_changed.connect(_on_stamina_changed)
		if not stats_controller.died.is_connected(_on_death):
			stats_controller.died.connect(_on_death)

func _physics_process(delta: float) -> void:
	if controller:
		current_input = controller.get_input()
	else:
		if not current_input:
			current_input = ControllerInput.new()
	
	if stats_controller:
		stats_controller.process_stats(delta)
	
	if state_machine and state_machine.current_state:
		state_machine.current_state.physics_process(delta)
		state_machine.current_state.handle_animation()
	
	update_air_time(delta)
	update_character_direction()
	apply_soft_collisions()
	move_and_slide()
	update_ui()

func _process(delta: float) -> void:
	update_stamina_regeneration(delta)

func get_controller_input() -> ControllerInput:
	return current_input

func update_air_time(delta: float) -> void:
	if not is_on_floor():
		air_time += delta
		if velocity.y > 0:
			effective_air_time += delta
	else:
		air_time = 0.0
		effective_air_time = 0.0

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func update_stamina_regeneration(delta: float) -> void:
	if stamina_current >= character_data.stamina_max:
		return
	
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
		return
	
	stamina_current += delta * character_data.stamina_regen_rate
	stamina_current = min(stamina_current, character_data.stamina_max)

func apply_soft_collisions() -> void:
	if not areas_handler or not areas_handler.soft_collision_area:
		return
	
	var current_state_name = state_machine.get_current_state_name() if state_machine else ""
	if current_state_name == "DeathState" or current_state_name == "AttackingState":
		return
	
	var push_vector = Vector2.ZERO
	var overlapping_bodies = areas_handler.soft_collision_area.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		if body == self:
			continue
		if not body.is_in_group("Enemy"):
			continue
		
		var distance_vector = global_position - body.global_position
		var distance = distance_vector.length()
		
		if distance < 1.0:
			distance = 1.0
		
		var push_strength = character_data.ai_soft_collision_strength / distance
		push_vector += distance_vector.normalized() * push_strength
	
	if push_vector.length() > 0:
		push_vector = push_vector.limit_length(character_data.ai_soft_collision_max_force)
		velocity.x += push_vector.x
		velocity.y += push_vector.y * 0.1

func update_character_direction() -> void:
	if state_machine.current_state and state_machine.current_state.name == "DeathState":
		return
	
	var input_direction = current_input.move_direction.x
	
	if state_machine.current_state and state_machine.current_state.name == "WallSlidingState":
		if ray_casts_handler and ray_casts_handler.left_wall_ray.is_colliding():
			body_node.scale.x = 1
		elif ray_casts_handler and ray_casts_handler.right_wall_ray.is_colliding():
			body_node.scale.x = -1
	elif state_machine.current_state and state_machine.current_state.name == "AttackingState":
		pass
	elif state_machine.current_state and state_machine.current_state.name == "DashAttackState":
		pass
	elif input_direction != 0:
		body_node.scale.x = -sign(input_direction)

func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

func reset_jump_state() -> void:
	jump_count = 0
	has_double_jump = false
	has_triple_jump = false
	can_wall_jump = false
	dash_count = 0

func reset_air_time() -> void:
	air_time = 0
	effective_air_time = 0

func apply_knockback(force: Vector2) -> void:
	if is_in_group("dead"):
		return
	
	if state_machine.current_state and state_machine.current_state.name == "DeathState":
		return
	
	if not character_data.can_receive_knockback:
		return
	
	var weight_multiplier = 100.0 / character_data.weight
	knockback_velocity = force * weight_multiplier
	knockback_timer = character_data.incoming_knockback_duration
	
	if state_machine.current_state:
		var knockback_state = state_machine.states.get("KnockbackState")
		if knockback_state:
			knockback_state.set_knockback(knockback_velocity)
	state_machine.transition_to("KnockbackState")

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_in_group("dead"):
		return
	
	if state_machine and state_machine.current_state:
		if state_machine.current_state.name == "DeathState":
			return
	
	was_hit_by_damage = true
	
	if stats_controller:
		stats_controller.take_damage(amount, attacker_position)
	else:
		print("Warning: No stats_controller on ", name)

func update_ui() -> void:
	if stamina_bar:
		stamina_bar.value = stamina_current
		stamina_bar.max_value = character_data.stamina_max
	if health_bar and stats_controller:
		health_bar.value = stats_controller.get_health()
		health_bar.max_value = stats_controller.get_max_health()

func get_attack_direction() -> float:
	return -body_node.scale.x

func get_facing_direction() -> float:
	return -body_node.scale.x

func get_wall_direction() -> float:
	if ray_casts_handler:
		if ray_casts_handler.left_wall_ray.is_colliding():
			return 1.0
		elif ray_casts_handler.right_wall_ray.is_colliding():
			return -1.0
	return 0.0

func _is_on_wall() -> bool:
	if not ray_casts_handler:
		return false
	return ray_casts_handler.left_wall_ray.is_colliding() or ray_casts_handler.right_wall_ray.is_colliding()

func is_on_wall_left() -> bool:
	if not ray_casts_handler:
		return false
	return ray_casts_handler.left_wall_ray.is_colliding()

func is_on_wall_right() -> bool:
	if not ray_casts_handler:
		return false
	return ray_casts_handler.right_wall_ray.is_colliding()

func _is_on_ceiling() -> bool:
	if not ray_casts_handler:
		return false
	return ray_casts_handler.ceiling_ray.is_colliding() or ray_casts_handler.ceiling_ray_2.is_colliding() or ray_casts_handler.ceiling_ray_3.is_colliding()

func set_weapon_visibility(mode: String) -> void:
	if not body_node:
		return
	
	var sword_f = body_node.get_node_or_null("body/armF_1/handF_1/swordF")
	var sword_b = body_node.get_node_or_null("body/armB_1/handB_1/swordB")
	var sword_body = body_node.get_node_or_null("body/swordBody")
	var sword_body_2 = body_node.get_node_or_null("body/swordBody2")
	
	if not sword_f or not sword_b or not sword_body or not sword_body_2:
		return
	
	match mode:
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

func cancel_big_jump_charge() -> void:
	big_jump_charged = false
	if timers_handler and timers_handler.big_jump_timer:
		timers_handler.big_jump_timer.stop()

func start_big_jump_charge() -> void:
	if not character_data.can_big_jump or not can_big_jump:
		return
	
	if timers_handler.big_jump_timer.time_left > 0:
		return
	
	can_big_jump = false
	timers_handler.big_jump_cooldown_timer.wait_time = character_data.big_jump_cooldown
	timers_handler.big_jump_cooldown_timer.start()
	timers_handler.big_jump_timer.wait_time = character_data.big_jump_charge_time
	timers_handler.big_jump_timer.start()

func execute_big_jump(direction: Vector2) -> void:
	if not character_data.can_big_jump:
		return
	
	if stamina_current < character_data.big_jump_stamina_cost:
		cancel_big_jump_charge()
		return
	
	stamina_current -= character_data.big_jump_stamina_cost
	stamina_regen_timer = character_data.stamina_regen_delay
	big_jump_direction = direction
	big_jump_charged = false
	
	var big_jump_state = state_machine.states.get("BigJumpingState")
	if big_jump_state:
		big_jump_state.set_direction(direction)

func execute_damage_to_entities() -> void:
	if not character_data.can_take_damage:
		return
	
	if not areas_handler or not areas_handler.attack_area:
		return
	
	var overlapping_bodies = areas_handler.attack_area.get_overlapping_bodies()
	if overlapping_bodies.is_empty():
		return
	
	var damage = 0
	match attack_count:
		1:
			damage = character_data.attack_1_dmg
		2:
			damage = character_data.attack_2_dmg
		3:
			damage = character_data.attack_3_dmg
	
	var base_knockback_force = character_data.outgoing_knockback_force
	if attack_count == 3:
		base_knockback_force *= character_data.outgoing_knockback_multiplier_combo3
	
	var attack_dir = get_attack_direction()
	var hit_count = 0
	
	for entity in overlapping_bodies:
		if entity == self:
			continue
		
		if entity.is_in_group("dead"):
			continue
		
		hit_count += 1
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if character_data.can_apply_knockback:
			var target_weight_multiplier = 1.0
			if entity.has_method("character_data") and entity.character_data:
				if entity.character_data.has("weight"):
					target_weight_multiplier = 100.0 / entity.character_data.weight
			
			var knockback_force = Vector2(
				attack_dir * base_knockback_force * character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier,
				-abs(character_data.jump_velocity * character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier)
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * character_data.self_knockback_multiplier,
			-abs(character_data.jump_velocity * character_data.self_knockback_vertical_multiplier)
		)
		pending_knockback_force = reaction_force

func on_wall_jump() -> void:
	can_wall_jump = true

func update_attack_animations() -> void:
	var anim_name = ""
	if is_on_floor():
		match attack_count:
			1: 
				anim_name = "Attack_ground_1"
				set_weapon_visibility("back")
			2:  
				anim_name = "Attack_ground_2"
				set_weapon_visibility("front")
			3:  
				anim_name = "Attack_ground_3"
				set_weapon_visibility("both")
	else:
		match attack_count:
			1: 
				anim_name = "Attack_air_1"
				set_weapon_visibility("back")
			2:  
				anim_name = "Attack_air_2"
				set_weapon_visibility("front")
			3:  
				anim_name = "Attack_air_3"
				set_weapon_visibility("both")
	
	if animation_player.current_animation != anim_name:
		play_animation(anim_name)

func perform_attack() -> void:
	if not character_data.can_attack:
		return
	
	state_machine.transition_to("AttackingState")

func perform_air_attack() -> void:
	if not character_data.can_attack or not character_data.can_air_attack:
		return
	
	state_machine.transition_to("AttackingState")

func handle_ground_jump() -> bool:
	if not character_data.can_jump:
		return false
	velocity.y = character_data.jump_velocity
	jump_count = 1
	has_double_jump = true
	return true

func process_big_jump_input() -> bool:
	if not character_data.can_big_jump:
		return false
	
	if big_jump_charged and current_input.dash:
		if current_input.move_direction.x < 0:
			execute_big_jump(Vector2(-1, 0))
			return true
		elif current_input.move_direction.x > 0:
			execute_big_jump(Vector2(1, 0))
			return true
		elif current_input.jump:
			execute_big_jump(Vector2(0, -1))
			return true
	
	if big_jump_charged and not current_input.dash:
		cancel_big_jump_charge()
	
	return false

func _on_state_changed(old_state: State, new_state: State) -> void:
	if old_state:
		previous_state = old_state.name
	
	if stats_controller:
		if old_state:
			stats_controller.on_state_exit(old_state.name)
		if new_state:
			stats_controller.on_state_enter(new_state.name)

func _on_attack_area_body_entered(body: Node2D) -> void:
	if state_machine.current_state and state_machine.current_state.name == "DashAttackState":
		var dash_state = state_machine.current_state as DashAttackState
		if dash_state:
			dash_state.apply_damage_to_entity(body)

func _on_damage_timer_timeout() -> void:
	if state_machine.current_state and state_machine.current_state.name == "AttackingState":
		var attack_state = state_machine.current_state as AttackingState
		if attack_state:
			attack_state.apply_damage()

func _on_animation_finished(anim_name: String) -> void:
	if state_machine.current_state and state_machine.current_state.name == "AttackingState":
		var attack_state = state_machine.current_state as AttackingState
		if attack_state:
			attack_state.on_animation_finished()
	elif anim_name == "Big_attack_prepare":
		play_animation("Big_attack")
	elif anim_name == "Big_attack_landing":
		if state_machine.current_state and state_machine.current_state.name == "BigAttackLandingState":
			var landing_state = state_machine.current_state as BigAttackLandingState
			if landing_state:
				landing_state.on_animation_finished()
	elif anim_name == "Death":
		pass

func _on_health_changed(_new_health: int) -> void:
	pass

func _on_stamina_changed(_new_stamina: float) -> void:
	pass

func _on_death() -> void:
	state_machine.transition_to("DeathState")
