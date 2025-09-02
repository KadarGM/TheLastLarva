extends State
class_name AttackingState

var attack_completed: bool = false
var animation_started: bool = false
var can_combo: bool = false
var attack_direction: Vector2 = Vector2.ZERO

func enter() -> void:
	if not character.character_data.can_attack:
		transition_to_appropriate_state()
		return
	
	if not character.is_on_floor() and not character.character_data.can_air_attack:
		state_machine.transition_to("JumpingState")
		return
	
	if character.timers_handler.before_attack_timer.time_left > 0:
		transition_to_appropriate_state()
		return
	
	if character.stamina_current < character.character_data.attack_stamina_cost:
		transition_to_appropriate_state()
		return
	
	character.stamina_current -= character.character_data.attack_stamina_cost
	character.stamina_regen_timer = character.character_data.stamina_regen_delay
	
	character.attack_count += 1
	if character.attack_count > 2:
		character.attack_count = 1
	
	attack_completed = false
	animation_started = false
	can_combo = false
	character.damage_applied_this_attack = false
	character.velocity_before_attack = character.velocity.x
	
	determine_attack_direction()
	set_attack_area_collision()
	
	character.timers_handler.hide_weapon_timer.stop()
	character.timers_handler.attack_cooldown_timer.stop()
	character.timers_handler.attack_cooldown_timer.start()
	
	character.timers_handler.before_attack_timer.wait_time = character.character_data.attack_cooldown
	character.timers_handler.before_attack_timer.start()
	
	character.timers_handler.damage_timer.wait_time = character.character_data.damage_delay
	character.timers_handler.damage_timer.start()
	
	if character.is_on_floor():
		character.velocity.x = 0

func exit() -> void:
	character.timers_handler.hide_weapon_timer.start()
	if character.attack_count >= 2:
		character.attack_count = 0
	
	reset_attack_area_collision()

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 0.5)
	else:
		if not character.damage_applied_this_attack:
			character.velocity.x = 0
	
	check_combo_input()
	
	if attack_completed and not can_combo:
		transition_to_next_state()

func determine_attack_direction() -> void:
	var input = character.get_controller_input()
	
	if not character.is_on_floor():
		if abs(input.move_direction.x) > 0.1:
			attack_direction.x = sign(input.move_direction.x)
		else:
			attack_direction.x = character.get_facing_direction()
		
		if input.down or input.move_direction.y > 0:
			attack_direction.y = 1.0
			print("[DEBUG] Air Attack Direction: DOWN")
		elif input.jump or input.move_direction.y < 0:
			attack_direction.y = -1.0
			print("[DEBUG] Air Attack Direction: UP")
		else:
			attack_direction.y = 0.0
			print("[DEBUG] Air Attack Direction: FORWARD")
	else:
		attack_direction.x = character.get_facing_direction()
		attack_direction.y = 0.0
		print("[DEBUG] Ground Attack Direction: FORWARD")

func set_attack_area_collision() -> void:
	if not character.areas_handler or not character.areas_handler.attack_area:
		return
	
	var attack_area = character.areas_handler.attack_area
	var collision_polygon_2d = attack_area.get_node_or_null("CollisionPolygon2D")
	var collision_polygon_up = attack_area.get_node_or_null("CollisionPolygonUp")
	var collision_polygon_down = attack_area.get_node_or_null("CollisionPolygonDown")
	
	if not collision_polygon_2d or not collision_polygon_up or not collision_polygon_down:
		return
	
	collision_polygon_2d.disabled = true
	collision_polygon_up.disabled = true
	collision_polygon_down.disabled = true
	
	if not character.is_on_floor() and attack_direction.y != 0:
		if attack_direction.y > 0:
			collision_polygon_down.disabled = false
			print("[DEBUG] Using DOWN collision polygon")
		else:
			collision_polygon_up.disabled = false
			print("[DEBUG] Using UP collision polygon")
	else:
		collision_polygon_2d.disabled = false
		print("[DEBUG] Using FORWARD collision polygon")

func reset_attack_area_collision() -> void:
	if not character.areas_handler or not character.areas_handler.attack_area:
		return
	
	var attack_area = character.areas_handler.attack_area
	var collision_polygon_2d = attack_area.get_node_or_null("CollisionPolygon2D")
	var collision_polygon_up = attack_area.get_node_or_null("CollisionPolygonUp")
	var collision_polygon_down = attack_area.get_node_or_null("CollisionPolygonDown")
	
	if collision_polygon_2d:
		collision_polygon_2d.disabled = false
	if collision_polygon_up:
		collision_polygon_up.disabled = true
	if collision_polygon_down:
		collision_polygon_down.disabled = true

func check_combo_input() -> void:
	if attack_completed:
		return
	
	var input = character.get_controller_input()
	
	if input.attack_pressed and character.timers_handler.before_attack_timer.is_stopped():
		if character.attack_count < 2:
			can_combo = true

func apply_damage() -> void:
	print("[DEBUG] apply_damage called!")
	
	if character.damage_applied_this_attack:
		print("[DEBUG] Damage already applied, skipping")
		return
	
	character.damage_applied_this_attack = true
	
	if not character.areas_handler or not character.areas_handler.attack_area:
		print("[DEBUG] No attack area found!")
		return
	
	var overlapping_bodies = character.areas_handler.attack_area.get_overlapping_bodies()
	print("[DEBUG] Overlapping bodies count: ", overlapping_bodies.size())
	
	if overlapping_bodies.is_empty():
		print("[DEBUG] No bodies to damage")
		return
	
	var damage = 0
	match character.attack_count:
		1:
			damage = character.character_data.attack_1_dmg
		2:
			damage = character.character_data.attack_2_dmg
	
	print("[DEBUG] Damage to apply: ", damage)
	
	var base_knockback_force = character.character_data.outgoing_knockback_force
	var hit_count = 0
	
	for entity in overlapping_bodies:
		if entity == character:
			continue
		
		if entity.is_in_group("dead"):
			continue
		
		if entity.has_method("state_machine") and entity.state_machine:
			if entity.state_machine.current_state and entity.state_machine.current_state.name == "DeathState":
				continue
		
		if not entity.has_method("take_damage"):
			continue
		
		hit_count += 1
		print("[DEBUG] Hit entity: ", entity.name)
		
		entity.take_damage(damage, character.global_position)
		
		if not entity.is_in_group("dead") and entity.has_method("apply_knockback"):
			var can_apply_knockback = true
			
			if entity.has_method("state_machine") and entity.state_machine:
				if entity.state_machine.current_state and entity.state_machine.current_state.name == "DeathState":
					can_apply_knockback = false
			
			if can_apply_knockback and entity.has_method("stats_controller") and entity.stats_controller:
				if entity.stats_controller.is_invulnerable():
					can_apply_knockback = false
			
			if can_apply_knockback and entity.has_method("character_data") and entity.character_data:
				if not entity.character_data.can_receive_knockback:
					can_apply_knockback = false
			
			if can_apply_knockback:
				var target_weight_multiplier = 1.0
				if entity.has_method("character_data") and entity.character_data:
					if entity.character_data.has("weight"):
						target_weight_multiplier = 100.0 / entity.character_data.weight
				
				var knockback_force = Vector2.ZERO
				
				if not character.is_on_floor() and attack_direction.y != 0:
					if attack_direction.y > 0:
						knockback_force = Vector2(
							attack_direction.x * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier * 0.5,
							abs(base_knockback_force * character.character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier * 2.0)
						)
					else:
						knockback_force = Vector2(
							attack_direction.x * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier * 0.5,
							-abs(character.character_data.jump_velocity * character.character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier * 1.5)
						)
				else:
					knockback_force = Vector2(
						attack_direction.x * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier,
						-abs(character.character_data.jump_velocity * character.character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier)
					)
				
				print("[DEBUG] Applying knockback to entity: ", knockback_force)
				entity.apply_knockback(knockback_force)
				
				apply_stun_to_entity(entity)
	
	print("[DEBUG] Total hit count: ", hit_count)
	
	if hit_count > 0 and character.character_data.can_apply_knockback:
		print("[DEBUG] Applying self knockback...")
		apply_self_knockback(hit_count)
	else:
		print("[DEBUG] No self knockback - hit_count: ", hit_count, ", can_apply_knockback: ", character.character_data.can_apply_knockback)

func apply_stun_to_entity(entity: Node2D) -> void:
	if not entity.has_method("character_data") or not entity.character_data:
		return
	
	if not entity.has_method("apply_stun"):
		return
	
	var entity_poise = entity.character_data.poise if entity.character_data.has("poise") else 0
	var stun_duration = character.character_data.stun_on_hit_base
	
	if entity_poise > 0:
		stun_duration *= (1.0 - (entity_poise / 100.0))
	
	stun_duration = max(stun_duration, character.character_data.stun_on_hit_min)
	
	entity.apply_stun(stun_duration)

func apply_self_knockback(hit_count: int) -> void:
	# Základní síla by měla být nezávislá na outgoing_knockback_force
	var base_horizontal_force = character.character_data.self_knockback_multiplier * 100.0
	var base_vertical_force = abs(character.character_data.jump_velocity) * character.character_data.self_knockback_vertical_multiplier
	var self_knockback_force = Vector2.ZERO
	
	print("[DEBUG] Base horizontal force: ", base_horizontal_force)
	print("[DEBUG] Base vertical force: ", base_vertical_force)
	print("[DEBUG] Attack direction: ", attack_direction)
	
	if not character.is_on_floor():
		if attack_direction.y > 0:
			# Útok dolů - odkopne nahoru
			self_knockback_force = Vector2(
				-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_down_horizontal,
				-base_vertical_force * character.character_data.self_knockback_down_vertical
			)
			print("[DEBUG] Self knockback DOWN attack: ", self_knockback_force)
		elif attack_direction.y < 0:
			# Útok nahoru - odkopne dolů
			self_knockback_force = Vector2(
				-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_up_horizontal,
				base_vertical_force * character.character_data.self_knockback_up_vertical
			)
			print("[DEBUG] Self knockback UP attack: ", self_knockback_force)
		else:
			# Útok dopředu ve vzduchu
			self_knockback_force = Vector2(
				-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_forward_horizontal,
				-base_vertical_force * character.character_data.self_knockback_forward_vertical
			)
			print("[DEBUG] Self knockback FORWARD air attack: ", self_knockback_force)
	else:
		# Útok na zemi
		self_knockback_force = Vector2(
			-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_ground_horizontal,
			-base_vertical_force * character.character_data.self_knockback_ground_vertical
		)
		print("[DEBUG] Self knockback GROUND attack: ", self_knockback_force)
	
	# Násobení podle počtu zasažených nepřátel
	var final_multiplier = 1.0 + (hit_count - 1) * character.character_data.self_knockback_hit_multiplier
	self_knockback_force *= final_multiplier
	
	print("[DEBUG] Final multiplier (hit_count ", hit_count, "): ", final_multiplier)
	print("[DEBUG] Self knockback before limit: ", self_knockback_force)
	
	# Limit maximální síly
	if self_knockback_force.length() > character.character_data.self_knockback_max_force:
		self_knockback_force = self_knockback_force.limit_length(character.character_data.self_knockback_max_force)
		print("[DEBUG] Self knockback limited to max force: ", self_knockback_force)
	
	print("[DEBUG] Velocity before knockback: ", character.velocity)
	character.velocity += self_knockback_force
	print("[DEBUG] Velocity after knockback: ", character.velocity)

func on_animation_finished() -> void:
	attack_completed = true
	
	if can_combo:
		state_machine.transition_to("AttackingState")

func transition_to_next_state() -> void:
	if character.is_on_floor():
		var input = character.get_controller_input()
		if abs(input.move_direction.x) > 0.1:
			state_machine.transition_to("WalkingState")
		else:
			state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func transition_to_appropriate_state() -> void:
	if character.is_on_floor():
		state_machine.transition_to("IdleState")
	else:
		state_machine.transition_to("JumpingState")

func handle_animation() -> void:
	if animation_started:
		return
	animation_started = true
	
	var anim_name = ""
	if character.is_on_floor():
		match character.attack_count:
			1: 
				anim_name = "Attack_ground_1"
				character.set_weapon_visibility("back")
			2:  
				anim_name = "Attack_ground_2"
				character.set_weapon_visibility("front")
	else:
		match character.attack_count:
			1: 
				anim_name = "Attack_air_1"
				character.set_weapon_visibility("back")
			2:  
				anim_name = "Attack_air_2"
				character.set_weapon_visibility("front")
	
	if character.animation_player.current_animation != anim_name:
		character.play_animation(anim_name)
