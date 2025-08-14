extends Control
#class_name BigJumpController
#
#@export var owner_body: CharacterManager
#@export var state_machine: CallableStateMachine
#@export var character_data: CharacterData
#@export var timers_handler: TimersHandler
#@export var ray_casts_handler: RayCastsHandler
#@export var stats_controller: StatsController
#@export var debug_helper: DebugHelper
#
#var big_jump_charged: bool = false
#var big_jump_direction: Vector2 = Vector2.ZERO
#var can_big_jump: bool = true
#var can_charge_big_jump: bool = false
#
#func setup(body: CharacterManager, sm: CallableStateMachine, data: CharacterData, th: TimersHandler, rch: RayCastsHandler, sc: StatsController, dh: DebugHelper):
	#owner_body = body
	#state_machine = sm
	#character_data = data
	#timers_handler = th
	#ray_casts_handler = rch
	#stats_controller = sc
	#debug_helper = dh
	#
	#setup_signals()
#
#func setup_signals():
	#if timers_handler.big_jump_timer:
		#timers_handler.big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
	#if timers_handler.big_jump_cooldown_timer:
		#timers_handler.big_jump_cooldown_timer.timeout.connect(_on_big_jump_cooldown_timer_timeout)
#
#
#func process_big_jump_input() -> bool:
	#if big_jump_charged and Input.is_action_pressed("J_dash"):
		#if Input.is_action_just_pressed("A_left"):
			#execute_directional_big_jump(Vector2(-1, 0))
			#return true
		#elif Input.is_action_just_pressed("D_right"):
			#execute_directional_big_jump(Vector2(1, 0))
			#return true
		#elif Input.is_action_just_pressed("W_jump"):
			#execute_directional_big_jump(Vector2(0, -1))
			#return true
	#
	#if big_jump_charged and Input.is_action_just_released("J_dash"):
		#cancel_charge()
	#
	#return false
#
#func process_big_jump_movement() -> void:
	#if owner_body.current_state != state_machine.State.BIG_JUMPING:
		#return
		#
	#if big_jump_direction.y < 0:
		#owner_body.velocity.x = 0
		#owner_body.velocity.y = -character_data.big_jump_vertical_speed
	#elif big_jump_direction.x != 0:
		#owner_body.velocity.x = big_jump_direction.x * character_data.big_jump_horizontal_speed
		#owner_body.velocity.y = 0
#
#func update_big_jump_stamina(delta: float) -> void:
	#if owner_body.current_state == state_machine.State.BIG_JUMPING:
		#if stats_controller:
			#stats_controller.drain_stamina(character_data.big_jump_stamina_drain_rate, delta)
			#if stats_controller.get_stamina() <= 0:
				#end_big_jump()
#
#func execute_directional_big_jump(direction: Vector2) -> void:
	#if not character_data.can_big_jump:
		#if debug_helper and debug_helper.console_debug:
			#debug_helper.log_ability_blocked("Big Jump", "Not available")
		#return
	#
	#big_jump_charged = false
	#big_jump_direction = direction
	#
	#if debug_helper and debug_helper.console_debug:
		#debug_helper.log_jump("Big Jump")
	#
	#state_machine.transition_to(state_machine.State.BIG_JUMPING)
#
#func can_charge() -> bool:
	#if not character_data.can_big_jump and not character_data.can_dash_attack:
		#return false
	#return true
#
#func start_charge() -> void:
	#if big_jump_charged or timers_handler.big_jump_timer.time_left > 0 or not can_big_jump:
		#return
		#
	#can_big_jump = false
	#timers_handler.big_jump_cooldown_timer.start()
	#timers_handler.big_jump_timer.start()
#
#func cancel_charge() -> void:
	#if timers_handler.big_jump_timer.time_left > 0:
		#timers_handler.big_jump_timer.stop()
	#big_jump_charged = false
#
#func check_big_jump_collision() -> void:
	#if owner_body.current_state != state_machine.State.BIG_JUMPING:
		#return
		#
	#var _ceil = ray_casts_handler.ceiling_ray.is_colliding() or ray_casts_handler.ceiling_ray_2.is_colliding() or ray_casts_handler.ceiling_ray_3.is_colliding()
	#var left = ray_casts_handler.left_wall_ray.is_colliding()
	#var right = ray_casts_handler.right_wall_ray.is_colliding()
	#
	#if big_jump_direction.y < 0 and _ceil:
		#end_big_jump()
	#elif big_jump_direction.x < 0 and left:
		#end_big_jump()
	#elif big_jump_direction.x > 0 and right:
		#end_big_jump()
#
#func check_big_jump_input_release() -> void:
	#if owner_body.current_state != state_machine.State.BIG_JUMPING:
		#return
		#
	#if big_jump_direction.x < 0 and not Input.is_action_pressed("A_left"):
		#end_big_jump()
	#elif big_jump_direction.x > 0 and not Input.is_action_pressed("D_right"):
		#end_big_jump()
	#elif big_jump_direction.y < 0 and not Input.is_action_pressed("W_jump"):
		#end_big_jump()
#
#func end_big_jump() -> void:
	#big_jump_direction = Vector2.ZERO
	#state_machine.transition_to(state_machine.State.JUMPING)
#
#func perform_charge_attempt() -> void:
	#if not can_charge():
		#return
		#
	#if Input.is_action_pressed("J_dash") and owner_body.velocity.x == 0 and can_big_jump:
		#start_charge()
#
#func perform_wall_charge_attempt() -> void:
	#if not can_charge():
		#return
		#
	#if Input.is_action_pressed("J_dash") and can_big_jump:
		#start_charge()
	#elif Input.is_action_just_released("J_dash"):
		#cancel_charge()
#
#func on_state_enter(new_state) -> void:
	#match new_state:
		#state_machine.State.BIG_JUMPING:
			#big_jump_charged = false
		#state_machine.State.DASH_ATTACK:
			#big_jump_charged = false
		#state_machine.State.STUNNED:
			#cancel_charge()
#
#func on_state_exit(_old_state) -> void:
	#pass
#
#func is_charged() -> bool:
	#return big_jump_charged
#
#func is_available() -> bool:
	#return can_big_jump
#
#func get_direction() -> Vector2:
	#return big_jump_direction
#
#func _on_big_jump_timer_timeout() -> void:
	#big_jump_charged = true
#
#func _on_big_jump_cooldown_timer_timeout() -> void:
	#can_big_jump = true
