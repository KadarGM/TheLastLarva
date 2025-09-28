extends State
class_name JumpingState

func update(delta: float):
	var h_input = Input.get_axis("left", "right")

	character.velocity.y += character.character_data.gravity * delta
	character.velocity.x = h_input * character.character_data.move_speed

	if h_input != 0 and character.sprite:
		character.sprite.scale.x = sign(h_input) * abs(character.sprite.scale.x)

	if character.is_on_floor():
		if h_input != 0:
			change_state("WalkingState")
			character.animation_player.play("Walking")
		else:
			change_state("IdleState")
			character.animation_player.play("Idle")
	
	char_orientation(character.sprite, h_input)
