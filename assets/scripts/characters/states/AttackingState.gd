extends State
class_name AttackingState

var attack_completed: bool = false
var animation_started: bool = false
var attack_direction: Vector2 = Vector2.ZERO
var pogo_attack: bool = false
var self_knockback_applied: bool = false

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
	
	attack_completed = false
	animation_started = false
	pogo_attack = false
	self_knockback_applied = false
	character.damage_applied_this_attack = false
	character.velocity_before_attack = character.velocity.x
	
	character.log_attack_start()
	
	determine_attack_direction()
	set_attack_area_collision()
	
	character.timers_handler.hide_weapon_timer.stop()
	character.timers_handler.before_attack_timer.wait_time = character.character_data.attack_cooldown
	character.timers_handler.before_attack_timer.start()
	character.timers_handler.damage_timer.wait_time = character.character_data.damage_delay
	character.timers_handler.damage_timer.start()
	
	if character.is_on_floor():
		character.velocity.x = 0

func exit() -> void:
	character.timers_handler.hide_weapon_timer.start()
	reset_attack_area_collision()
	pogo_attack = false

func physics_process(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y += character.gravity * delta
		character.velocity.x = move_toward(character.velocity.x, 0, character.character_data.speed * delta * 0.5)
	else:
		if not character.damage_applied_this_attack:
			character.velocity.x = 0
	
	if attack_completed:
		transition_to_next_state()

func determine_attack_direction() -> void:
	var input = character.get_controller_input()
	
	if not character.is_on_floor():
		if abs(input.move_direction.x) > 0.1:
			attack_direction.x = sign(input.move_direction.x)
		else:
			attack_direction.x = character.get_facing_direction()
		
		if input.move_direction.y > 0.5:
			attack_direction.y = 1.0
			pogo_attack = true
		elif input.move_direction.y < -0.5:
			attack_direction.y = -1.0
			pogo_attack = false
		else:
			attack_direction.y = 0.0
			pogo_attack = false
	else:
		attack_direction.x = character.get_facing_direction()
		attack_direction.y = 0.0
		pogo_attack = false

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
	
	if not character.is_on_floor():
		if attack_direction.y > 0:
			collision_polygon_down.disabled = false
		elif attack_direction.y < 0:
			collision_polygon_up.disabled = false
		elif abs(attack_direction.x) > 0:
			collision_polygon_2d.disabled = false
		else:
			collision_polygon_2d.disabled = false
	else:
		collision_polygon_2d.disabled = false

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

func apply_damage() -> void:
	if character.damage_applied_this_attack:
		return
	
	character.damage_applied_this_attack = true
	character.log_attack_damage()
	
	if not character.areas_handler or not character.areas_handler.attack_area:
		return
	
	var overlapping_bodies = character.areas_handler.attack_area.get_overlapping_bodies()
	
	if overlapping_bodies.is_empty():
		return
	
	var base_damage = character.character_data.attack_1_dmg
	var base_knockback_force = character.character_data.outgoing_knockback_force
	var hit_count = 0
	var was_parried = false
	
	for entity in overlapping_bodies:
		if entity == character:
			continue
		
		if entity.is_in_group("dead"):
			continue
		
		if entity.has_method("state_machine") and entity.state_machine:
			if entity.state_machine.current_state and entity.state_machine.current_state.name == "DeathState":
				continue
			
			if entity.state_machine.current_state and entity.state_machine.current_state.name == "ParryState":
				var parry_state = entity.state_machine.current_state
				if parry_state.has_method("handle_incoming_attack"):
					if parry_state.handle_incoming_attack(character):
						character.log_got_parried()
						was_parried = true
						return
			
			if entity.state_machine.current_state and entity.state_machine.current_state.name == "BlockState":
				var block_state = entity.state_machine.current_state
				if block_state.has_method("handle_incoming_attack"):
					var blocked = block_state.handle_incoming_attack(character)
					if blocked:
						character.log_got_blocked()
						
						var damage = int(base_damage * entity.character_data.block_damage_reduction)
						
						hit_count += 1
						if entity.has_method("take_damage"):
							character.log_attack_hit(entity.name, damage)
							entity.take_damage(damage, character.global_position)
						continue
					else:
						hit_count += 1
						if entity.has_method("take_damage"):
							character.log_attack_hit(entity.name, base_damage)
							entity.take_damage(base_damage, character.global_position)
						
						var entity_direction = sign(entity.global_position.x - character.global_position.x)
						if entity_direction == 0:
							entity_direction = attack_direction.x
						
						var knockback_force = Vector2(
							entity_direction * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier,
							-abs(character.character_data.jump_velocity * character.character_data.outgoing_knockback_vertical_multiplier)
						)
						
						entity.apply_knockback(knockback_force)
						apply_stun_to_entity(entity)
						continue
		
		if not entity.has_method("take_damage"):
			continue
		
		hit_count += 1
		character.log_attack_hit(entity.name, base_damage)
		
		entity.take_damage(base_damage, character.global_position)
		
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
				
				var entity_direction = sign(entity.global_position.x - character.global_position.x)
				if entity_direction == 0:
					entity_direction = attack_direction.x
				
				var knockback_force = Vector2.ZERO
				
				if not character.is_on_floor() and attack_direction.y != 0:
					if attack_direction.y > 0:
						knockback_force = Vector2(
							entity_direction * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier * 0.5,
							abs(base_knockback_force * character.character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier * 2.0)
						)
					else:
						knockback_force = Vector2(
							entity_direction * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier * 0.5,
							-abs(character.character_data.jump_velocity * character.character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier * 1.5)
						)
				else:
					knockback_force = Vector2(
						entity_direction * base_knockback_force * character.character_data.outgoing_knockback_horizontal_multiplier * target_weight_multiplier,
						-abs(character.character_data.jump_velocity * character.character_data.outgoing_knockback_vertical_multiplier * target_weight_multiplier)
					)
				
				entity.apply_knockback(knockback_force)
				
				apply_stun_to_entity(entity)
	
	if hit_count > 0 and character.character_data.can_apply_knockback and not self_knockback_applied and not was_parried:
		apply_self_knockback()
		self_knockback_applied = true

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

func apply_self_knockback() -> void:
	var self_knockback_force = Vector2.ZERO
	
	if pogo_attack and not character.is_on_floor():
		var pogo_force = abs(character.character_data.jump_velocity) * character.character_data.self_knockback_down_vertical
		self_knockback_force = Vector2(0, -pogo_force)
		
		character.velocity.y = -pogo_force
		character.reset_air_time()
		
		if character.has_double_jump == false and character.jump_count >= 1:
			character.has_double_jump = true
	else:
		var base_horizontal_force = character.character_data.self_knockback_multiplier * 100.0
		var base_vertical_force = abs(character.character_data.jump_velocity) * character.character_data.self_knockback_vertical_multiplier
		
		if not character.is_on_floor():
			if attack_direction.y < 0:
				self_knockback_force = Vector2(
					-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_up_horizontal,
					base_vertical_force * character.character_data.self_knockback_up_vertical
				)
			else:
				self_knockback_force = Vector2(
					-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_forward_horizontal,
					-base_vertical_force * character.character_data.self_knockback_forward_vertical
				)
		else:
			self_knockback_force = Vector2(
				-attack_direction.x * base_horizontal_force * character.character_data.self_knockback_ground_horizontal,
				-base_vertical_force * character.character_data.self_knockback_ground_vertical
			)
		
		if self_knockback_force.length() > character.character_data.self_knockback_max_force:
			self_knockback_force = self_knockback_force.limit_length(character.character_data.self_knockback_max_force)
		
		character.velocity += self_knockback_force

func on_animation_finished() -> void:
	attack_completed = true

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
		anim_name = "Attack_ground_1"
		character.set_weapon_visibility("back")
	else:
		if attack_direction.y > 0:
			anim_name = "Attack_air_down"
			character.set_weapon_visibility("front")
		elif attack_direction.y < 0:
			anim_name = "Attack_air_up"
			character.set_weapon_visibility("back")
		elif abs(attack_direction.x) > 0:
			anim_name = "Attack_air"
			character.set_weapon_visibility("back")
		else:
			anim_name = "Attack_air"
			character.set_weapon_visibility("back")
	
	if character.animation_player.current_animation != anim_name:
		character.play_animation(anim_name)
