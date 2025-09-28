extends State
class_name WalkingState

func update(_delta: float):
	var h_input = Input.get_axis("left", "right")

	if h_input == 0:
		change_state("IdleState")
		character.animation_player.play("Idle")
		return
		
	if Input.is_action_just_pressed("jump") and character.is_on_floor():
		character.velocity.y = character.character_data.jump_velocity
		change_state("JumpingState")
		return
	
	if not character.is_on_floor():
		change_state("JumpingState")
		return

	character.velocity.x = h_input * character.character_data.move_speed

	char_orientation(character.sprite, h_input)
