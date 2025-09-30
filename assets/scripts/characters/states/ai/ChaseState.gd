extends State
class_name ChaseState

var jump_cooldown: float = 0.0

func enter() -> void:
	jump_cooldown = 0.0

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if jump_cooldown > 0:
		jump_cooldown -= delta
	
	var ai_controller = character.controller as AIController
	if not ai_controller:
		state_machine.transition_to("PatrolState")
		return
	
	if not ai_controller.player_in_detection_zone:
		state_machine.transition_to("SearchState")
		return
	
	if not ai_controller.can_see_player:
		state_machine.transition_to("WaitState")
		return
	
	if ai_controller.player_in_attack_range:
		state_machine.transition_to("AIAttackState")
		return
	
	var chase_direction = ai_controller.chase_direction
	
	if chase_direction != 0:
		character.velocity.x = chase_direction * character.character_data.speed * character.character_data.ai_chase_speed_multiplier
		ai_controller.movement_direction = chase_direction
		
		if character.is_on_floor() and should_jump(ai_controller):
			character.velocity.y = character.character_data.jump_velocity
			jump_cooldown = character.character_data.ai_jump_cooldown
	else:
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta)

func should_jump(ai_controller: AIController) -> bool:
	if jump_cooldown > 0 or not character.is_on_floor():
		return false
	
	if not ai_controller.target_player:
		return false
	
	var y_difference = character.global_position.y - ai_controller.target_player.global_position.y
	
	if y_difference > 50 and y_difference < abs(character.character_data.jump_velocity) * 0.8:
		return true
	
	var chase_direction = ai_controller.chase_direction
	
	if chase_direction > 0:
		if character.ray_casts_handler.right_wall_ray.is_colliding():
			return true
		if character.ray_casts_handler.ground_check_ray.is_colliding():
			if not character.ray_casts_handler.ground_check_ray_2.is_colliding():
				return ai_controller.can_see_player
	elif chase_direction < 0:
		if character.ray_casts_handler.left_wall_ray.is_colliding():
			return true
		if character.ray_casts_handler.ground_check_ray.is_colliding():
			if not character.ray_casts_handler.ground_check_ray_3.is_colliding():
				return ai_controller.can_see_player
	
	return false

func handle_animation() -> void:
	if not character.is_on_floor():
		character.play_animation("Jump")
	else:
		character.play_animation("Walk")
