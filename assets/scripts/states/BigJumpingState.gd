extends State
class_name BigJumpingState

var direction: Vector2 = Vector2.ZERO
var stamina_drain_timer: float = 0.0

func enter() -> void:
	character.big_jump_charged = false
	character.invulnerability_temp = true

func exit() -> void:
	direction = Vector2.ZERO
	character.invulnerability_temp = false

func physics_process(delta: float) -> void:
	if direction.y < 0:
		character.velocity.x = 0
		character.velocity.y = -character.character_data.big_jump_vertical_speed
	elif direction.x != 0:
		character.velocity.x = direction.x * character.character_data.big_jump_horizontal_speed
		character.velocity.y = 0
	
	character.stamina_current -= character.character_data.big_jump_stamina_drain_rate * delta
	if character.stamina_current <= 0:
		character.stamina_current = 0
		state_machine.transition_to("JumpingState")
		return
	
	check_collision()
	check_input_release()
	
	character.play_animation("Dash")

func check_collision() -> void:
	if direction.y < 0 and character._is_on_ceiling():
		state_machine.transition_to("JumpingState")
	elif direction.x < 0 and character.is_on_wall_left():
		state_machine.transition_to("JumpingState")
	elif direction.x > 0 and character.is_on_wall_right():
		state_machine.transition_to("JumpingState")

func check_input_release() -> void:
	if direction.x < 0 and not Input.is_action_pressed("A_left"):
		state_machine.transition_to("JumpingState")
	elif direction.x > 0 and not Input.is_action_pressed("D_right"):
		state_machine.transition_to("JumpingState")
	elif direction.y < 0 and not Input.is_action_pressed("W_jump"):
		state_machine.transition_to("JumpingState")

func set_direction(dir: Vector2) -> void:
	direction = dir
