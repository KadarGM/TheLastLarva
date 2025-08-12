extends State
class_name AttackingState

var queued_attack: bool = false
var attack_finished: bool = false
var current_animation: String = ""

func enter() -> void:
	queued_attack = false
	attack_finished = false
	current_animation = ""
	
	if character.before_attack_timer and not character.before_attack_timer.is_stopped():
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
	
	if character.previous_state == "AttackingState" and character.count_of_attack < 3:
		character.count_of_attack += 1
	else:
		character.count_of_attack = 1
	
	character.on_attack_state_enter()
	character.before_attack_timer.start()
	
	update_current_animation()
	character.animation_player.play(current_animation)

func exit() -> void:
	character.on_attack_state_exit()

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
	
	character.process_attack_movement()
	
	if Input.is_action_just_pressed("L_attack") and not queued_attack:
		queued_attack = true
	
	if attack_finished:
		handle_attack_end()

func handle_attack_end() -> void:
	if queued_attack and character.count_of_attack < 3:
		if character.stamina_current >= character.character_data.attack_stamina_cost:
			if character.before_attack_timer.is_stopped():
				character.stamina_current -= character.character_data.attack_stamina_cost
				character.stamina_regen_timer = character.character_data.stamina_regen_delay
				character.before_attack_timer.start()
				state_machine.transition_to("AttackingState")
				return
	
	if character.is_on_floor():
		state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func on_animation_finished() -> void:
	attack_finished = true

func apply_damage() -> void:
	if character.damage_applied_this_attack:
		return
	
	character.damage_applied_this_attack = true
	character.execute_damage_to_entities()

func update_current_animation() -> void:
	if character.is_on_floor():
		match character.count_of_attack:
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
		match character.count_of_attack:
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
