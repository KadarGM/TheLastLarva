extends State
class_name AttackingState

var attack_completed: bool = false
var knockback_applied: bool = false
var animation_started: bool = false
var can_combo: bool = false

func enter() -> void:
	if not character.character_data.can_attack:
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	if not character.is_on_floor() and not character.character_data.can_air_attack:
		state_machine.transition_to("JumpingState")
		return
	
	if character.timers_handler.before_attack_timer.time_left > 0:
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	if character.stamina_current < character.character_data.attack_stamina_cost:
		if character.is_on_floor():
			state_machine.transition_to("IdleState")
		else:
			state_machine.transition_to("JumpingState")
		return
	
	character.stamina_current -= character.character_data.attack_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	character.attack_count += 1
	if character.attack_count > 3:
		character.attack_count = 1
	
	attack_completed = false
	knockback_applied = false
	animation_started = false
	can_combo = false
	character.damage_applied_this_attack = false
	character.velocity_before_attack = character.velocity.x
	
	character.timers_handler.hide_weapon_timer.stop()
	character.timers_handler.attack_cooldown_timer.stop()
	character.timers_handler.attack_cooldown_timer.start()
	
	character.timers_handler.before_attack_timer.wait_time = character.character_data.attack_cooldown
	character.timers_handler.before_attack_timer.start()
	
	character.timers_handler.damage_timer.wait_time = character.character_data.damage_delay
	character.timers_handler.damage_timer.start()

func exit() -> void:
	character.timers_handler.hide_weapon_timer.start()
	if character.attack_count >= 3:
		character.attack_count = 0

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
	process_attack_movement(delta)
	check_combo_input()
	
	if attack_completed and not can_combo:
		transition_to_next_state()

func process_attack_movement(delta: float) -> void:
	var input = character.get_controller_input()
	var _input_direction = input.move_direction.x
	var attack_direction = character.get_attack_direction()
	
	if character.is_on_floor():
		var movement_multiplier = character.character_data.ground_attack_force_multiplier
		var friction = character.character_data.attack_movement_friction * character.character_data.ground_friction_multiplier
		
		if character.attack_count == 1:
			character.velocity.x = attack_direction * character.character_data.attack_movement_force * movement_multiplier * 0.8
		elif character.attack_count == 2:
			character.velocity.x = attack_direction * character.character_data.attack_movement_force * movement_multiplier * 0.8
		elif character.attack_count == 3:
			character.velocity.x = attack_direction * character.character_data.attack_movement_force * movement_multiplier
		
		character.velocity.x = move_toward(character.velocity.x, 0, friction * delta)
	else:
		var air_multiplier = character.character_data.air_attack_force_multiplier
		
		if character.attack_count == 1:
			character.velocity.x += attack_direction * character.character_data.attack_movement_force * air_multiplier * 0.8
		elif character.attack_count == 2:
			character.velocity.x += attack_direction * character.character_data.attack_movement_force * air_multiplier * 0.8
		elif character.attack_count == 3:
			character.velocity.x += attack_direction * character.character_data.attack_movement_force * air_multiplier
		
		character.velocity.x = clamp(character.velocity.x, -character.character_data.speed, character.character_data.speed)

func check_combo_input() -> void:
	if attack_completed:
		return
	
	var input = character.get_controller_input()
	
	if input.attack_pressed and character.timers_handler.before_attack_timer.is_stopped():
		if character.attack_count < 3:
			can_combo = true

func apply_damage() -> void:
	if character.damage_applied_this_attack:
		return
	
	character.damage_applied_this_attack = true
	character.execute_damage_to_entities()
	
	if character.pending_knockback_force != Vector2.ZERO and not knockback_applied:
		knockback_applied = true
		character.velocity = character.pending_knockback_force
		character.pending_knockback_force = Vector2.ZERO

func on_animation_finished() -> void:
	attack_completed = true
	
	if can_combo:
		state_machine.transition_to("AttackingState")

func transition_to_next_state() -> void:
	if character.is_on_floor():
		var input = character.get_controller_input()
		if abs(input.move_direction.x) > 0.1:
			state_machine.transition_to("WalkingState")
		else:
			state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func handle_animation() -> void:
	if not animation_started:
		animation_started = true
		character.update_attack_animations()
