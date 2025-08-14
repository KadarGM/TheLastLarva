extends State
class_name BigJumpingState

var direction: Vector2 = Vector2.ZERO
var stamina_drain_timer: float = 0.0

func enter() -> void:
	character.big_jump_charged = false
	character.invulnerability_temp = true
	character.can_big_jump = false
	character.timers_handler.big_jump_cooldown_timer.wait_time = character.character_data.big_jump_cooldown_after_use
	character.timers_handler.big_jump_cooldown_timer.start()

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

func check_collision() -> void:
	if direction.y < 0 and character._is_on_ceiling():
		state_machine.transition_to("JumpingState")
	elif direction.x < 0 and character.is_on_wall_left():
		state_machine.transition_to("JumpingState")
	elif direction.x > 0 and character.is_on_wall_right():
		state_machine.transition_to("JumpingState")

func check_input_release() -> void:
	var input = character.get_controller_input()
	if direction.x < 0 and input.move_direction.x >= 0:
		state_machine.transition_to("JumpingState")
	elif direction.x > 0 and input.move_direction.x <= 0:
		state_machine.transition_to("JumpingState")
	elif direction.y < 0 and not input.jump:
		state_machine.transition_to("JumpingState")

func set_direction(dir: Vector2) -> void:
	direction = dir

func handle_animation() -> void:
	character.play_animation("Dash")
