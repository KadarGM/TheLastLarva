extends State
class_name SearchState

var search_timer: float = 3.0
var search_direction: float = 1.0

func enter() -> void:
	search_timer = 3.0
	
	var ai_controller = character.controller as AIController
	if ai_controller:
		if ai_controller.last_known_player_position != Vector2.ZERO:
			var direction = ai_controller.last_known_player_position.x - character.global_position.x
			search_direction = sign(direction) if direction != 0 else ai_controller.movement_direction
		else:
			search_direction = ai_controller.movement_direction

func exit() -> void:
	var ai_controller = character.controller as AIController
	if ai_controller:
		ai_controller.movement_direction = search_direction

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	search_timer -= delta
	
	if search_timer <= 0:
		state_machine.transition_to("PatrolState")
		return
	
	var ai_controller = character.controller as AIController
	if ai_controller:
		if ai_controller.player_in_detection_zone and ai_controller.can_see_player:
			state_machine.transition_to("ChaseState")
			return
	
	if character.is_on_floor():
		character.velocity.x = search_direction * character.character_data.speed * character.character_data.ai_patrol_speed_multiplier * 1.2
		
		if check_edge_or_wall():
			search_direction *= -1

func check_edge_or_wall() -> bool:
	if not character.ray_casts_handler:
		return false
	
	if search_direction > 0:
		if character.ray_casts_handler.right_wall_ray.is_colliding():
			return true
		if character.ray_casts_handler.ground_check_ray.is_colliding():
			if not character.ray_casts_handler.ground_check_ray_2.is_colliding():
				return true
	else:
		if character.ray_casts_handler.left_wall_ray.is_colliding():
			return true
		if character.ray_casts_handler.ground_check_ray.is_colliding():
			if not character.ray_casts_handler.ground_check_ray_3.is_colliding():
				return true
	
	return false

func handle_animation() -> void:
	if not character.is_on_floor():
		character.play_animation("Jump")
	else:
		character.play_animation("Walk")
