extends State
class_name FallingState

func update(delta: float):
	var h_input = Input.get_axis("left", "right")

	character.velocity.y += character.character_data.gravity * delta
	character.velocity.x = h_input * character.character_data.move_speed

	if character.is_on_floor():
		if h_input != 0:
			change_state("WalkingState")
			return
		else:
			change_state("IdleState")
			return
