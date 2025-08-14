extends BaseController
class_name AIController

@export_category("Detection")
@export var detection_range: float = 600.0
@export var attack_range: float = 50.0
@export var view_ray: RayCast2D

@export_category("Behavior")
@export var patrol_speed_multiplier: float = 0.5
@export var chase_speed_multiplier: float = 1.0
@export var flee_health_threshold: float = 0.2
@export var think_time: float = 0.2
@export var patrol_idle_chance: float = 0.3
@export var patrol_state_min_time: float = 1.0
@export var patrol_state_max_time: float = 4.0

@export_category("Patrol")
@export var patrol_points: Array[Vector2] = []
@export var auto_generate_patrol_points: bool = true
@export var patrol_distance: float = 200.0

var target: Node2D = null
var current_patrol_index: int = 0
var think_timer: float = 0.0
var patrol_timer: float = 0.0
var patrol_direction: float = 1.0
var last_jump_time: float = 0.0
var jump_cooldown: float = 1.5
var attack_combo_timer: float = 0.0
var can_see_target: bool = false
var is_fleeing: bool = false
var target_in_detection: bool = false
var target_in_attack_range: bool = false

func _ready() -> void:
	if auto_generate_patrol_points and patrol_points.is_empty() and character:
		await character.ready
		patrol_points.append(character.global_position + Vector2(patrol_distance, 0))
		patrol_points.append(character.global_position + Vector2(-patrol_distance, 0))
	
	start_patrol_timer()

func update_input() -> void:
	think_timer -= get_physics_process_delta_time()
	patrol_timer -= get_physics_process_delta_time()
	attack_combo_timer -= get_physics_process_delta_time()
	
	if think_timer <= 0:
		think_timer = think_time
		update_ai_decision()
	
	execute_behavior()

func update_ai_decision() -> void:
	if not character:
		return
	
	find_target()
	check_target_visibility()
	check_flee_condition()
	
	if patrol_timer <= 0:
		change_patrol_state()

func find_target() -> void:
	target = null
	target_in_detection = false
	target_in_attack_range = false
	
	var potential_targets = get_tree().get_nodes_in_group("player")
	var nearest_distance = INF
	
	for potential_target in potential_targets:
		if potential_target == character:
			continue
		
		var distance = character.global_position.distance_to(potential_target.global_position)
		if distance < detection_range and distance < nearest_distance:
			nearest_distance = distance
			target = potential_target
			target_in_detection = true
			
			if distance <= attack_range:
				target_in_attack_range = true

func check_target_visibility() -> void:
	if not target or not view_ray:
		can_see_target = false
		return
	
	view_ray.target_position = character.to_local(target.global_position)
	view_ray.force_raycast_update()
	
	can_see_target = not view_ray.is_colliding()

func check_flee_condition() -> void:
	if not character.stats_controller:
		is_fleeing = false
		return
	
	var health_percentage = float(character.stats_controller.get_health()) / float(character.stats_controller.get_max_health())
	is_fleeing = health_percentage <= flee_health_threshold

func execute_behavior() -> void:
	input.reset()
	
	if character.stats_controller and character.stats_controller.get_health() <= 0:
		return
	
	if is_fleeing:
		execute_flee()
	elif target_in_attack_range and can_see_target:
		execute_attack()
	elif target_in_detection and can_see_target:
		execute_chase()
	else:
		execute_patrol()

func execute_patrol() -> void:
	if not character.character_data.can_patrol:
		return
	
	if patrol_timer > 0 and patrol_timer < patrol_state_max_time * 0.5:
		return
	
	if patrol_points.size() > 1:
		var target_point = patrol_points[current_patrol_index]
		var distance = character.global_position.distance_to(target_point)
		
		if distance < 50:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			start_patrol_timer()
		else:
			var direction = sign(target_point.x - character.global_position.x)
			input.move_direction.x = direction * patrol_speed_multiplier
	else:
		input.move_direction.x = patrol_direction * patrol_speed_multiplier
	
	handle_obstacle_detection()

func execute_chase() -> void:
	if not target or not character.character_data.can_chase:
		return
	
	var direction = sign(target.global_position.x - character.global_position.x)
	input.move_direction.x = direction * chase_speed_multiplier
	
	var y_difference = character.global_position.y - target.global_position.y
	if y_difference > 50 and y_difference < 200 and character.is_on_floor():
		handle_jump()
	
	handle_obstacle_detection()
	
	if randf() < 0.05 and character.can_dash:
		input.dash_pressed = true

func execute_attack() -> void:
	if not target or not character.character_data.can_attack:
		return
	
	var direction = sign(target.global_position.x - character.global_position.x)
	input.move_direction.x = direction * 0.3
	
	if character.timers_handler and character.timers_handler.before_attack_timer.is_stopped():
		input.attack_pressed = true
		attack_combo_timer = 0.5
	elif attack_combo_timer > 0 and randf() < 0.4:
		input.attack_pressed = true
		attack_combo_timer = 0.5

func execute_flee() -> void:
	if target:
		var direction = sign(character.global_position.x - target.global_position.x)
		input.move_direction.x = direction * chase_speed_multiplier
		
		if randf() < 0.1 and character.can_dash:
			input.dash_pressed = true
	else:
		input.move_direction.x = patrol_direction * chase_speed_multiplier
	
	handle_obstacle_detection()

func handle_obstacle_detection() -> void:
	if not character.ray_casts_handler:
		return
	
	var moving_left = input.move_direction.x < 0
	var moving_right = input.move_direction.x > 0
	
	if moving_left and character.ray_casts_handler.left_wall_ray.is_colliding():
		handle_obstacle()
	elif moving_right and character.ray_casts_handler.right_wall_ray.is_colliding():
		handle_obstacle()
	
	if character.is_on_floor():
		if moving_right and character.ray_casts_handler.ground_check_ray.is_colliding():
			if not character.ray_casts_handler.ground_check_ray_2.is_colliding():
				handle_edge()
		elif moving_left and character.ray_casts_handler.ground_check_ray.is_colliding():
			if not character.ray_casts_handler.ground_check_ray_3.is_colliding():
				handle_edge()

func handle_obstacle() -> void:
	if target_in_detection and can_see_target:
		handle_jump()
	else:
		patrol_direction *= -1
		input.move_direction.x *= -1
		start_patrol_timer()

func handle_edge() -> void:
	if target_in_detection and can_see_target:
		return
	else:
		patrol_direction *= -1
		input.move_direction.x *= -1
		start_patrol_timer()

func handle_jump() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_jump_time < jump_cooldown:
		return
	
	if character.is_on_floor():
		input.jump_pressed = true
		last_jump_time = current_time

func start_patrol_timer() -> void:
	patrol_timer = randf_range(patrol_state_min_time, patrol_state_max_time)

func change_patrol_state() -> void:
	if target_in_detection:
		return
	
	if randf() < patrol_idle_chance:
		input.move_direction.x = 0
	else:
		if randf() < 0.5:
			patrol_direction *= -1
	
	start_patrol_timer()
