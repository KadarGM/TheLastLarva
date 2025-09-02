extends BaseController
class_name AIController

enum AIState {
	PATROL,
	IDLE,
	CHASE,
	ATTACK,
	SEARCH,
	WAIT
}

@export var detection_area: Area2D
@export var attack_area: Area2D
@export var view_ray: RayCast2D
@export var shape_detection: CollisionShape2D

var target_player: Node2D = null
var player_in_detection_zone: bool = false
var player_in_attack_range: bool = false
var can_see_player: bool = false
var chase_direction: int = 0
var movement_direction: int = 1
var last_known_player_position: Vector2 = Vector2.ZERO

var current_ai_state: AIState = AIState.PATROL
var state_timer: float = 0.0
var attack_cooldown: float = 0.0
var jump_cooldown: float = 0.0
var dash_cooldown: float = 0.0
var combo_count: int = 0
var combo_window: float = 0.0
var emergency_timer: float = 0.0
var search_direction: int = 1
var last_player_height_diff: float = 0.0

func _ready() -> void:
	setup_signals()
	setup_detection()
	start_patrol()

func setup(_char: CharacterManager) -> void:
	character = _char

func setup_signals() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

func setup_detection() -> void:
	if shape_detection:
		shape_detection.call_deferred("set_disabled", true)
	
	if attack_area:
		attack_area.monitoring = true
	
	if detection_area:
		detection_area.monitoring = true

func update_input() -> void:
	input.reset()
	
	if not character or not character.character_data:
		return
	
	if not character.character_data.ai_enabled:
		return
	
	var delta = get_physics_process_delta_time()
	
	update_timers(delta)
	update_detection()
	update_ai_state()
	generate_input_from_ai_state()

func update_timers(delta: float) -> void:
	if state_timer > 0:
		state_timer -= delta
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	if jump_cooldown > 0:
		jump_cooldown -= delta
	
	if dash_cooldown > 0:
		dash_cooldown -= delta
	
	if combo_window > 0:
		combo_window -= delta
		if combo_window <= 0:
			combo_count = 0
	
	if emergency_timer > 0:
		emergency_timer -= delta
		if emergency_timer <= 0:
			call_deferred("set_shape_detection_enabled", false)

func update_detection() -> void:
	if target_player and is_instance_valid(target_player):
		update_view_ray()
		update_chase_direction()
		check_attack_range()
	else:
		can_see_player = false
		chase_direction = 0

func update_view_ray() -> void:
	if not view_ray or not target_player:
		return
	
	view_ray.target_position = character.to_local(target_player.global_position)
	view_ray.force_raycast_update()
	
	can_see_player = not view_ray.is_colliding() or view_ray.get_collider() == target_player
	
	if can_see_player:
		last_known_player_position = target_player.global_position

func update_chase_direction() -> void:
	if not target_player or not is_instance_valid(target_player):
		chase_direction = 0
		return
	
	var x_difference = target_player.global_position.x - character.global_position.x
	var tolerance = character.character_data.ai_attack_range * 0.5
	
	if abs(x_difference) < tolerance:
		chase_direction = 0
	else:
		chase_direction = sign(x_difference)
	
	last_player_height_diff = target_player.global_position.y - character.global_position.y

func check_attack_range() -> void:
	if not attack_area or not target_player:
		return
	
	if not attack_area.monitoring:
		return
	
	var bodies = attack_area.get_overlapping_bodies()
	player_in_attack_range = false
	
	for body in bodies:
		if body == target_player or body.is_in_group("Player"):
			player_in_attack_range = true
			break

func update_ai_state() -> void:
	match current_ai_state:
		AIState.PATROL:
			if player_in_detection_zone and can_see_player:
				change_ai_state(AIState.CHASE)
			elif state_timer <= 0:
				if randf() < character.character_data.ai_patrol_idle_chance:
					change_ai_state(AIState.IDLE)
				else:
					movement_direction *= -1
					start_patrol()
		
		AIState.IDLE:
			if player_in_detection_zone and can_see_player:
				change_ai_state(AIState.CHASE)
			elif state_timer <= 0:
				change_ai_state(AIState.PATROL)
		
		AIState.CHASE:
			if player_in_attack_range:
				change_ai_state(AIState.ATTACK)
			elif not player_in_detection_zone:
				last_known_player_position = target_player.global_position if target_player else character.global_position
				change_ai_state(AIState.SEARCH)
			elif not can_see_player:
				change_ai_state(AIState.WAIT)
		
		AIState.ATTACK:
			if not player_in_attack_range:
				if player_in_detection_zone and can_see_player:
					change_ai_state(AIState.CHASE)
				else:
					change_ai_state(AIState.SEARCH)
		
		AIState.SEARCH:
			if player_in_detection_zone and can_see_player:
				change_ai_state(AIState.CHASE)
			elif state_timer <= 0:
				change_ai_state(AIState.PATROL)
		
		AIState.WAIT:
			if player_in_attack_range:
				change_ai_state(AIState.ATTACK)
			elif can_see_player and abs(chase_direction) > 0:
				change_ai_state(AIState.CHASE)
			elif state_timer <= 0:
				change_ai_state(AIState.SEARCH)

func change_ai_state(new_state: AIState) -> void:
	current_ai_state = new_state
	
	match new_state:
		AIState.PATROL:
			start_patrol()
		AIState.IDLE:
			state_timer = randf_range(character.character_data.ai_patrol_state_min_time, character.character_data.ai_patrol_state_max_time)
		AIState.SEARCH:
			state_timer = character.character_data.ai_patience_time
			search_direction = sign(last_known_player_position.x - character.global_position.x)
			if search_direction == 0:
				search_direction = movement_direction
		AIState.WAIT:
			state_timer = character.character_data.ai_lose_sight_time
		AIState.ATTACK:
			attack_cooldown = character.character_data.ai_reaction_time

func start_patrol() -> void:
	state_timer = randf_range(character.character_data.ai_patrol_state_min_time, character.character_data.ai_patrol_state_max_time)
	
	if randf() < 0.5:
		movement_direction *= -1

func generate_input_from_ai_state() -> void:
	var character_state = character.state_machine.get_current_state_name() if character.state_machine else ""
	
	if character_state == "DeathState" or character_state == "KnockbackState" or character_state == "StunnedState":
		return
	
	match current_ai_state:
		AIState.PATROL:
			handle_patrol_input()
		AIState.IDLE:
			input.move_direction.x = 0
		AIState.CHASE:
			handle_chase_input()
		AIState.ATTACK:
			handle_attack_input()
		AIState.SEARCH:
			handle_search_input()
		AIState.WAIT:
			handle_wait_input()

func handle_patrol_input() -> void:
	if check_edge_or_wall():
		movement_direction *= -1
		start_patrol()
	
	input.move_direction.x = movement_direction * character.character_data.ai_patrol_speed_multiplier

func handle_chase_input() -> void:
	if chase_direction != 0:
		input.move_direction.x = chase_direction * character.character_data.ai_chase_speed_multiplier
		movement_direction = chase_direction
		
		if should_dash():
			input.dash_pressed = true
			dash_cooldown = character.character_data.ai_dash_cooldown
		
		if should_jump():
			input.jump_pressed = true
			jump_cooldown = character.character_data.ai_jump_cooldown

func handle_attack_input() -> void:
	var character_state = character.state_machine.get_current_state_name() if character.state_machine else ""
	
	if target_player:
		var dir_to_player = sign(target_player.global_position.x - character.global_position.x)
		if dir_to_player != 0:
			movement_direction = dir_to_player
	
	if character_state != "AttackingState":
		if attack_cooldown <= 0 and character.timers_handler.before_attack_timer.is_stopped():
			input.attack_pressed = true
			attack_cooldown = character.character_data.attack_cooldown
			combo_count += 1
			combo_window = character.character_data.ai_combo_window
			
			if combo_count > 2:
				combo_count = 1
				attack_cooldown = character.character_data.attack_cooldown * character.character_data.ai_combo_cooldown_multiplier
	else:
		if combo_window > 0 and combo_count < 2 and randf() < character.character_data.ai_combo_chance:
			if character.timers_handler.before_attack_timer.is_stopped():
				input.attack_pressed = true
				combo_window = character.character_data.ai_combo_window

func handle_search_input() -> void:
	if check_edge_or_wall():
		search_direction *= -1
	
	input.move_direction.x = search_direction * character.character_data.ai_search_speed_multiplier

func handle_wait_input() -> void:
	input.move_direction.x = 0
	
	if character.character_data.ai_jump_when_player_above and last_player_height_diff < -character.character_data.ai_jump_height_threshold:
		if jump_cooldown <= 0:
			input.jump_pressed = true
			jump_cooldown = character.character_data.ai_jump_cooldown

func should_jump() -> bool:
	if jump_cooldown > 0 or not character.is_on_floor():
		return false
	
	if not target_player:
		return false
	
	if character.character_data.ai_jump_when_player_above and last_player_height_diff < -character.character_data.ai_jump_height_threshold:
		if last_player_height_diff > -character.character_data.ai_jump_height_max:
			return true
	
	if character.character_data.ai_wall_climb_when_needed:
		if chase_direction > 0 and character.ray_casts_handler.right_wall_ray.is_colliding():
			return true
		elif chase_direction < 0 and character.ray_casts_handler.left_wall_ray.is_colliding():
			return true
	
	if check_edge_ahead() and can_see_player:
		return true
	
	return false

func should_dash() -> bool:
	if not character.character_data.ai_can_dash:
		return false
	
	if dash_cooldown > 0:
		return false
	
	if not character.can_dash:
		return false
	
	if not target_player or not can_see_player:
		return false
	
	var distance = abs(target_player.global_position.x - character.global_position.x)
	
	if distance > character.character_data.ai_dash_distance_threshold:
		return true
	
	return false

func check_edge_or_wall() -> bool:
	return check_wall_ahead() or check_edge_ahead()

func check_wall_ahead() -> bool:
	if not character.ray_casts_handler:
		return false
	
	if movement_direction > 0:
		return character.ray_casts_handler.right_wall_ray.is_colliding()
	else:
		return character.ray_casts_handler.left_wall_ray.is_colliding()

func check_edge_ahead() -> bool:
	if not character.ray_casts_handler or not character.is_on_floor():
		return false
	
	if movement_direction > 0:
		if character.ray_casts_handler.ground_check_ray.is_colliding():
			return not character.ray_casts_handler.ground_check_ray_2.is_colliding()
	else:
		if character.ray_casts_handler.ground_check_ray.is_colliding():
			return not character.ray_casts_handler.ground_check_ray_3.is_colliding()
	
	return false

func set_shape_detection_enabled(enabled: bool) -> void:
	if shape_detection:
		shape_detection.disabled = not enabled

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		target_player = body
		player_in_detection_zone = true
		emergency_timer = 0
		call_deferred("set_shape_detection_enabled", true)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == target_player:
		player_in_detection_zone = false
		player_in_attack_range = false
		emergency_timer = character.character_data.ai_lose_sight_time * 2

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body != character and body.has_method("take_damage"):
		if body.is_in_group("dead"):
			return
		if body == target_player or body.is_in_group("Player"):
			player_in_attack_range = true
			if not target_player:
				target_player = body
				player_in_detection_zone = true

func _on_attack_area_body_exited(body: Node2D) -> void:
	if body == target_player or body.is_in_group("Player"):
		player_in_attack_range = false
