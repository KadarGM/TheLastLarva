extends State
class_name WalkingState

func update(_delta: float):
	var h_input = Input.get_axis("left", "right")

	if h_input == 0:
		change_state("IdleState")
		return
		
	if Input.is_action_just_pressed("jump") and character.is_on_floor():
		character.velocity.y = character.character_data.jump_velocity
		change_state("JumpingState")
		return
	
	if character.velocity.y > 0:
		change_state("FallingState")
		return
	
	if not character.is_on_floor():
		change_state("JumpingState")
		return

	character.velocity.x = h_input * character.character_data.move_speed
