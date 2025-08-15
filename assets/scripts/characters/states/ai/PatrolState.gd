extends State
class_name PatrolState

var patrol_timer: float = 0.0
var is_idle: bool = false
var movement_direction: float = 1.0

func enter() -> void:
	start_new_patrol_cycle()
	
	var ai_controller = character.controller as AIController
	if ai_controller:
		movement_direction = ai_controller.movement_direction if ai_controller.movement_direction != 0 else 1.0

func exit() -> void:
	var ai_controller = character.controller as AIController
	if ai_controller:
		ai_controller.movement_direction = movement_direction

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if not character.is_on_floor():
		return
	
	patrol_timer -= delta
	
	if patrol_timer <= 0:
		change_patrol_behavior()
		return
	
	if not is_idle:
		character.velocity.x = movement_direction * character.character_data.speed * character.character_data.ai_patrol_speed_multiplier
		
		if check_edge_or_wall():
			movement_direction *= -1
			start_new_patrol_cycle()
	else:
		character.velocity.x = 0
	
	check_for_player()

func check_edge_or_wall() -> bool:
	if not character.ray_casts_handler:
		return false
	
	if movement_direction > 0:
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

func change_patrol_behavior() -> void:
	if is_idle:
		is_idle = false
		if randf() < 0.5:
			movement_direction *= -1
	else:
		if randf() < character.character_data.ai_patrol_idle_chance:
			is_idle = true
		else:
			if randf() < 0.5:
				movement_direction *= -1
	
	start_new_patrol_cycle()

func start_new_patrol_cycle() -> void:
	var min_time = character.character_data.ai_patrol_state_min_time
	var max_time = character.character_data.ai_patrol_state_max_time
	patrol_timer = randf_range(min_time, max_time)

func check_for_player() -> void:
	var ai_controller = character.controller as AIController
	if not ai_controller:
		return
	
	if ai_controller.player_in_detection_zone and ai_controller.can_see_player:
		state_machine.transition_to("ChaseState")

func handle_animation() -> void:
	if is_idle:
		character.play_animation("Idle")
	else:
		character.play_animation("Walk")
