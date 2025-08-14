extends BaseController
class_name AIController

enum AIState {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	FLEE,
	DEAD
}

@export var detection_range: float = 300.0
@export var attack_range: float = 50.0
@export var flee_health_threshold: float = 0.2
@export var patrol_speed: float = 0.5
@export var chase_speed: float = 1.0
@export var patrol_points: Array[Vector2] = []
@export var think_time: float = 0.5

var current_state: AIState = AIState.IDLE
var target: Node2D = null
var current_patrol_index: int = 0
var think_timer: float = 0.0
var state_timer: float = 0.0
var last_jump_time: float = 0.0
var jump_cooldown: float = 2.0

func _ready() -> void:
	if patrol_points.is_empty() and character:
		patrol_points.append(character.global_position + Vector2(200, 0))
		patrol_points.append(character.global_position + Vector2(-200, 0))

func update_input() -> void:
	think_timer -= get_physics_process_delta_time()
	
	if think_timer <= 0:
		think_timer = think_time
		update_ai_state()
	
	execute_current_state()

func update_ai_state() -> void:
	if not character or not character.stats_controller:
		return
	
	if character.stats_controller.get_health() <= 0:
		current_state = AIState.DEAD
		return
	
	var health_percentage = float(character.stats_controller.get_health()) / float(character.stats_controller.get_max_health())
	if health_percentage <= flee_health_threshold:
		current_state = AIState.FLEE
		return
	
	target = find_nearest_enemy()
	
	if target:
		var distance_to_target = character.global_position.distance_to(target.global_position)
		
		if distance_to_target <= attack_range:
			current_state = AIState.ATTACK
		elif distance_to_target <= detection_range:
			current_state = AIState.CHASE
		else:
			current_state = AIState.PATROL
	else:
		if patrol_points.size() > 0:
			current_state = AIState.PATROL
		else:
			current_state = AIState.IDLE

func execute_current_state() -> void:
	input.reset()
	
	match current_state:
		AIState.IDLE:
			execute_idle()
		AIState.PATROL:
			execute_patrol()
		AIState.CHASE:
			execute_chase()
		AIState.ATTACK:
			execute_attack()
		AIState.FLEE:
			execute_flee()
		AIState.DEAD:
			execute_dead()

func execute_idle() -> void:
	state_timer += get_physics_process_delta_time()
	
	if state_timer > randf_range(2.0, 4.0):
		state_timer = 0.0
		if randf() > 0.5:
			input.move_direction.x = randf_range(-0.3, 0.3)

func execute_patrol() -> void:
	if patrol_points.is_empty():
		return
	
	var target_point = patrol_points[current_patrol_index]
	var distance = character.global_position.distance_to(target_point)
	
	if distance < 50:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	else:
		var direction = (target_point - character.global_position).normalized()
		input.move_direction.x = direction.x * patrol_speed
		
		handle_obstacle_jump()

func execute_chase() -> void:
	if not target:
		return
	
	var direction = (target.global_position - character.global_position).normalized()
	input.move_direction.x = direction.x * chase_speed
	
	handle_obstacle_jump()
	
	if randf() < 0.1 and character.can_dash:
		input.dash_pressed = true

func execute_attack() -> void:
	if not target:
		return
	
	var direction = (target.global_position - character.global_position).normalized()
	input.move_direction.x = direction.x * 0.5
	
	if randf() < 0.3:
		input.attack_pressed = true
	
	if randf() < 0.05 and character.stamina_current > 100:
		input.dash_pressed = true

func execute_flee() -> void:
	if target:
		var direction = (character.global_position - target.global_position).normalized()
		input.move_direction.x = direction.x * chase_speed
		
		if randf() < 0.2 and character.can_dash:
			input.dash_pressed = true
	else:
		input.move_direction.x = randf_range(-1, 1)
	
	handle_obstacle_jump()

func execute_dead() -> void:
	input.reset()

func handle_obstacle_jump() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if current_time - last_jump_time < jump_cooldown:
		return
	
	if character.ray_casts_handler:
		var moving_left = input.move_direction.x < 0
		var moving_right = input.move_direction.x > 0
		
		if (moving_left and character.ray_casts_handler.left_wall_ray.is_colliding()) or \
		   (moving_right and character.ray_casts_handler.right_wall_ray.is_colliding()):
			if character.is_on_floor():
				input.jump_pressed = true
				last_jump_time = current_time

func find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("player")
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF
	
	for enemy in enemies:
		if enemy == character:
			continue
		
		var distance = character.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy
	
	return nearest_enemy
