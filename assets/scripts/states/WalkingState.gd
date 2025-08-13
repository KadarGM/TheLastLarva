extends State
class_name WalkingState

func enter() -> void:
	pass
	#character.count_of_attack = 0

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if not character.is_on_floor():
		state_machine.transition_to("JumpingState")
		return
	
	var input_direction = Input.get_axis("A_left", "D_right")
	
	if abs(input_direction) < 0.1:
		state_machine.transition_to("IdleState")
		return
	
	character.velocity.x = input_direction * character.character_data.speed
	
	process_input()

func process_input() -> void:
	if Input.is_action_just_pressed("W_jump"):
		if character.handle_ground_jump():
			state_machine.transition_to("JumpingState")
			return
	
	if Input.is_action_just_pressed("J_dash"):
		if character.big_jump_charged and Input.is_action_pressed("L_attack"):
			state_machine.transition_to("DashAttackState")
			return
		elif character.can_dash:
			state_machine.transition_to("DashingState")
			return
	
	if Input.is_action_just_pressed("L_attack"):
		if character.character_data.can_attack:
			state_machine.transition_to("AttackingState")
		return
	
	character.process_big_jump_input()

func handle_animation() -> void:
	if character.big_jump_charged and Input.is_action_pressed("J_dash"):
		character.play_animation("Big_jump_charge")
	else:
		character.play_animation("Walk")
