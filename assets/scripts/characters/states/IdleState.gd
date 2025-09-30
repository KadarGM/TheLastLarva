extends State
class_name IdleState

func update(delta: float) -> void:
	var h_input = Input.get_axis("left", "right")

	if h_input != 0 and character.is_on_floor():
		change_state("WalkingState")
		return

	if character.is_on_floor():
		if Input.is_action_just_pressed("jump"):
			character.velocity.y = character.character_data.jump_velocity
			change_state("JumpingState")
			return
	
	if character.velocity.y > 0:
		change_state("FallingState")
		return
	
	if not character.is_on_floor():
		character.velocity.y += character.character_data.gravity * delta

	character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.move_speed * 10 *delta)
