extends State
class_name WallJumpingState

var is_wall_jump_held: bool = false

func enter() -> void:
	var input = character.get_controller_input()
	character.timers_handler.wall_jump_control_timer.start()
	is_wall_jump_held = input.jump

func physics_process(delta: float) -> void:
	var input = character.get_controller_input()
	
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
		
		if character.velocity.y < 0:
			if input.jump_released or character._is_on_ceiling():
				character.velocity.y *= character.character_data.jump_release_multiplier
				is_wall_jump_held = false
	
	if character.is_on_floor():
		if abs(character.velocity.x) > 10:
			state_machine.transition_to("WalkingState")
		else:
			state_machine.transition_to("IdleState")
		return
	
	var left = character.ray_casts_handler.left_wall_ray.is_colliding()
	var right = character.ray_casts_handler.right_wall_ray.is_colliding()
	
	if (left or right) and character.velocity.y > 0 and character.character_data.can_wall_slide:
		state_machine.transition_to("WallSlidingState")
		return
	
	if character.timers_handler.wall_jump_control_timer.is_stopped():
		var input_direction = input.move_direction.x
		process_air_movement(input_direction)
	
	process_input()

func process_air_movement(input_direction: float) -> void:
	if not character.character_data.can_walk:
		return
	
	if input_direction:
		character.velocity.x = input_direction * character.character_data.speed
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * character.character_data.air_movement_friction)

func process_input() -> void:
	var input = character.get_controller_input()
	
	if input.jump_pressed:
		if character.has_double_jump and character.jump_count == 1:
			if character.character_data.can_double_jump:
				state_machine.transition_to("DoubleJumpingState")
	
	if input.dash_pressed and character.character_data.can_dash:
		if character.can_dash:
			state_machine.transition_to("DashingState")
	
	if input.attack_pressed:
		if character.big_jump_charged and input.dash:
			state_machine.transition_to("DashAttackState")
		else:
			character.perform_air_attack()
	
	if input.charge_jump_pressed:
		if character.character_data.can_big_attack:
			state_machine.transition_to("BigAttackState")

func handle_animation() -> void:
	if not character.animation_player.current_animation.begins_with("Attack_air"):
		character.play_animation("Jump")
