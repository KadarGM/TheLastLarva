extends State
class_name AttackingState

var queued_attack: bool = false
var attack_finished: bool = false
var current_animation: String = ""
var damage_applied: bool = false

func enter() -> void:
	queued_attack = false
	attack_finished = false
	damage_applied = false
	current_animation = ""
	
	if character.timers_handler.before_attack_timer and not character.timers_handler.before_attack_timer.is_stopped():
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
	
	character.velocity_before_attack = character.velocity.x
	
	if character.timers_handler and character.timers_handler.damage_timer:
		character.timers_handler.damage_timer.wait_time = character.character_data.damage_delay
		character.timers_handler.damage_timer.start()
	
	character.timers_handler.before_attack_timer.wait_time = character.character_data.attack_cooldown
	character.timers_handler.before_attack_timer.start()
	
	update_current_animation()
	character.animation_player.stop()
	character.animation_player.play(current_animation)

func exit() -> void:
	character.pending_knockback_force = Vector2.ZERO
	if character.timers_handler and character.timers_handler.hide_weapon_timer:
		character.timers_handler.hide_weapon_timer.wait_time = character.character_data.hide_weapon_time
		character.timers_handler.hide_weapon_timer.start()

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
	process_attack_movement()
	
	if character.pending_knockback_force != Vector2.ZERO:
		character.velocity += character.pending_knockback_force
		character.pending_knockback_force = Vector2.ZERO

	if Input.is_action_just_pressed("L_attack") and not queued_attack:
		if character.attack_count < 3:
			queued_attack = true
	
	if attack_finished:
		handle_attack_end()

func process_attack_movement() -> void:
	var overlapping_bodies = character.areas_handler.attack_area.get_overlapping_bodies()
	var has_nearby_enemy = false
	
	for entity in overlapping_bodies:
		if entity != character:
			has_nearby_enemy = true
			break
	
	if has_nearby_enemy:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.attack_movement_friction * character.character_data.enemy_nearby_friction_multiplier)
		return
	
	if character.is_on_floor():
		var attack_force = character.character_data.attack_movement_force * character.character_data.ground_attack_force_multiplier
		if character.attack_count == 3:
			attack_force *= character.character_data.attack_movement_multiplier
		character.velocity.x = character.get_attack_direction() * attack_force
	else:
		var air_attack_force = character.character_data.attack_movement_force * character.character_data.air_attack_force_multiplier
		character.velocity.x = character.get_attack_direction() * air_attack_force
	
	if character.is_on_floor():
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.attack_movement_friction * character.character_data.ground_friction_multiplier)
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.attack_movement_friction * character.character_data.air_friction_multiplier)

func handle_attack_end() -> void:
	if queued_attack and character.attack_count < 3:
		if character.stamina_current >= character.character_data.attack_stamina_cost:
			if character.timers_handler.before_attack_timer.is_stopped():
				enter()
				return
	
	if character.is_on_floor():
		state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func on_animation_finished() -> void:
	attack_finished = true

func apply_damage() -> void:
	if damage_applied:
		return
	
	damage_applied = true
	execute_damage_to_entities()

func execute_damage_to_entities() -> void:
	if not character.character_data.can_take_damage:
		return
	
	var overlapping_bodies = character.areas_handler.attack_area.get_overlapping_bodies()
	if overlapping_bodies.is_empty():
		return
	
	var damage = 0
	match character.attack_count:
		1:
			damage = character.character_data.attack_1_dmg
		2:
			damage = character.character_data.attack_2_dmg
		3:
			damage = character.character_data.attack_3_dmg
	
	var base_knockback_force = character.character_data.knockback_force
	if character.attack_count == 3:
		base_knockback_force *= character.character_data.knockback_force_multiplier
	
	var attack_dir = character.get_attack_direction()
	var hit_count = 0
	
	for entity in overlapping_bodies:
		if entity == character:
			continue
		
		hit_count += 1
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if character.character_data.can_take_knockback:
			var knockback_force = Vector2(
				attack_dir * base_knockback_force,
				character.character_data.jump_velocity * character.character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * character.character_data.knockback_reaction_multiplier * character.character_data.knockback_reaction_force_multiplier,
			character.character_data.jump_velocity * character.character_data.knockback_reaction_jump_multiplier
		)
		character.pending_knockback_force = reaction_force

func update_current_animation() -> void:
	if character.is_on_floor():
		match character.attack_count:
			1: 
				current_animation = "Attack_ground_1"
				character.set_weapon_visibility("back")
			2:  
				current_animation = "Attack_ground_2"
				character.set_weapon_visibility("front")
			3:  
				current_animation = "Attack_ground_3"
				character.set_weapon_visibility("both")
	else:
		match character.attack_count:
			1: 
				current_animation = "Attack_air_1"
				character.set_weapon_visibility("back")
			2:  
				current_animation = "Attack_air_2"
				character.set_weapon_visibility("front")
			3:  
				current_animation = "Attack_air_3"
				character.set_weapon_visibility("both")

func handle_animation() -> void:
	pass
