extends Control
class_name StatsController

@export var owner_body: CharacterManager
@export var character_data: CharacterData
@export var state_machine: CallableStateMachine
@export var timers_handler: TimersHandler
@export var areas_handler: AreasHandler
@export var movement_controller: MovementController
@export var debug_helper: DebugHelper

var health_current: int
var stamina_current: float
var stamina_regen_timer: float = 0.0
var invulnerability_temp: bool = false

var damage_check_timer: float = 0.0
var damage_check_interval: float = 0.5

signal health_changed(new_health: int)
signal stamina_changed(new_stamina: float)
signal died()

func setup(body: CharacterManager, data: CharacterData, sm: CallableStateMachine, th: TimersHandler, ah: AreasHandler, mc: MovementController, dh: DebugHelper):
	owner_body = body
	character_data = data
	state_machine = sm
	timers_handler = th
	areas_handler = ah
	movement_controller = mc
	debug_helper = dh
	
	health_current = character_data.health_max
	stamina_current = character_data.stamina_max
	
	setup_signals()

func setup_signals():
	if areas_handler and areas_handler.damage_area:
		areas_handler.damage_area.body_entered.connect(_on_damage_area_body_entered)
	if timers_handler and timers_handler.invulnerability_timer:
		timers_handler.invulnerability_timer.timeout.connect(_on_invulnerability_timer_timeout)

func process_stats(delta: float) -> void:
	if owner_body.current_state != state_machine.State.DEATH:
		update_stamina_regeneration(delta)
		check_continuous_damage(delta)
	check_death()

func update_stamina_regeneration(delta: float) -> void:
	if stamina_current >= character_data.stamina_max:
		return
	
	if stamina_regen_timer > 0:
		stamina_regen_timer -= delta
		return
	
	stamina_current += delta * character_data.stamina_regen_rate
	stamina_current = min(stamina_current, character_data.stamina_max)
	stamina_changed.emit(stamina_current)

func check_continuous_damage(delta: float) -> void:
	if not character_data.can_get_damage:
		return
	
	if character_data.invulnerability or invulnerability_temp:
		return
	
	damage_check_timer -= delta
	if damage_check_timer > 0:
		return
	
	damage_check_timer = damage_check_interval
	
	var bodies_in_area = areas_handler.damage_area.get_overlapping_bodies()
	for body in bodies_in_area:
		if body.has_method("get_damage") and body != owner_body:
			var damage = body.get_damage()
			take_damage(damage, body.global_position)
			break

func consume_stamina(amount: float, apply_regen_delay: bool = true) -> bool:
	if stamina_current < amount:
		return false
	
	stamina_current -= amount
	stamina_current = max(0, stamina_current)
	
	if apply_regen_delay:
		stamina_regen_timer = character_data.stamina_regen_delay
	
	stamina_changed.emit(stamina_current)
	return true

func drain_stamina(amount: float, delta: float) -> void:
	stamina_current -= amount * delta
	stamina_current = max(0, stamina_current)
	stamina_changed.emit(stamina_current)

func restore_health(amount: int) -> void:
	health_current += amount
	health_current = min(health_current, character_data.health_max)
	health_changed.emit(health_current)

func restore_stamina(amount: float) -> void:
	stamina_current += amount
	stamina_current = min(stamina_current, character_data.stamina_max)
	stamina_changed.emit(stamina_current)

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not character_data.can_get_damage:
		if debug_helper and debug_helper.console_debug:
			debug_helper.log_ability_blocked("Damage", "Immune to damage")
		return
		
	if owner_body.current_state == state_machine.State.DEATH:
		return
	
	if character_data.invulnerability:
		if debug_helper and debug_helper.console_debug:
			debug_helper.log_ability_blocked("Damage", "Permanent invulnerability")
		return
	
	if invulnerability_temp:
		if debug_helper and debug_helper.console_debug:
			debug_helper.log_ability_blocked("Damage", "Temporary invulnerability")
		return
		
	health_current -= amount
	health_current = max(0, health_current)
	health_changed.emit(health_current)
	
	stamina_current -= character_data.damage_stamina_cost
	stamina_current = max(0, stamina_current)
	stamina_regen_timer = character_data.stamina_regen_delay
	stamina_changed.emit(stamina_current)
	
	activate_temporary_invulnerability()
	
	if character_data.can_get_knockback and owner_body.current_state != state_machine.State.KNOCKBACK:
		var knockback_direction: Vector2
		if attacker_position != Vector2.ZERO:
			knockback_direction = (owner_body.global_position - attacker_position).normalized()
		else:
			knockback_direction = Vector2(randf_range(-1, 1), 0).normalized()
		
		if knockback_direction.x == 0:
			knockback_direction.x = randf_range(-0.5, 0.5)
		
		var damage_knockback = Vector2(
			knockback_direction.x * character_data.damage_knockback_force * 10.0,
			-abs(character_data.damage_knockback_force * 0.8)
		)
		movement_controller.apply_knockback(damage_knockback)

func activate_temporary_invulnerability() -> void:
	invulnerability_temp = true
	if timers_handler and timers_handler.invulnerability_timer:
		timers_handler.invulnerability_timer.start()

func deactivate_temporary_invulnerability() -> void:
	invulnerability_temp = false

func check_death() -> void:
	if health_current <= 0 and owner_body.current_state != state_machine.State.DEATH:
		died.emit()
		state_machine.transition_to(state_machine.State.DEATH)

func get_health() -> int:
	return health_current

func get_stamina() -> float:
	return stamina_current

func get_max_health() -> int:
	return character_data.health_max

func get_max_stamina() -> float:
	return character_data.stamina_max

func is_invulnerable() -> bool:
	return character_data.invulnerability or invulnerability_temp

func is_stamina_available(amount: float) -> bool:
	return stamina_current >= amount

func is_alive() -> bool:
	return health_current > 0

func reset_stats() -> void:
	health_current = character_data.health_max
	stamina_current = character_data.stamina_max
	stamina_regen_timer = 0.0
	invulnerability_temp = false
	damage_check_timer = 0.0
	health_changed.emit(health_current)
	stamina_changed.emit(stamina_current)

func on_state_enter(new_state) -> void:
	match new_state:
		state_machine.State.DASHING, state_machine.State.DASH_ATTACK, state_machine.State.BIG_ATTACK:
			invulnerability_temp = true
		state_machine.State.DEATH:
			if areas_handler and areas_handler.damage_area:
				areas_handler.damage_area.monitorable = false

func on_state_exit(old_state) -> void:
	if old_state == state_machine.State.DASHING or old_state == state_machine.State.BIG_ATTACK or old_state == state_machine.State.DASH_ATTACK:
		invulnerability_temp = false

func _on_damage_area_body_entered(_body: Node2D) -> void:
	if not character_data.can_get_damage:
		return
		
	if character_data.invulnerability:
		return
		
	if invulnerability_temp:
		return
		
	if _body.has_method("get_damage") and _body != owner_body:
		var damage = _body.get_damage()
		take_damage(damage, _body.global_position)

func _on_invulnerability_timer_timeout() -> void:
	invulnerability_temp = false
