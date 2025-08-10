extends Control
class_name CombatController

@export var owner_body: CharacterManager
@export var state_machine: CallableStateMachine
@export var animation_player: AnimationPlayer
@export var body_node: BodyNode
@export var areas_handler: AreasHandler
@export var timers_handler: TimersHandler

var count_of_attack: int = 0
var velocity_before_attack: float = 0.0
var damage_applied_this_attack: bool = false
var pending_knockback_force: Vector2 = Vector2.ZERO
var dash_attack_damaged_entities: Array = []

func setup(body: CharacterManager, sm: CallableStateMachine, anim_player: AnimationPlayer, bn: BodyNode, ah: AreasHandler, th: TimersHandler):
	owner_body = body
	state_machine = sm
	animation_player = anim_player
	body_node = bn
	areas_handler = ah
	timers_handler = th
	
	setup_signals()
	set_weapon_visibility("hide")

func setup_signals():
	areas_handler.attack_area.body_entered.connect(_on_attack_area_body_entered)
	areas_handler.attack_area.body_exited.connect(_on_attack_area_body_exited)
	timers_handler.damage_timer.timeout.connect(_on_damage_timer_timeout)
	timers_handler.hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)

func reset_combat_state():
	count_of_attack = 0
	velocity_before_attack = 0.0
	damage_applied_this_attack = false
	pending_knockback_force = Vector2.ZERO
	dash_attack_damaged_entities.clear()

func can_perform_attack() -> bool:
	if not owner_body.character_data.can_attack:
		return false
	if not timers_handler.before_attack_timer.is_stopped():
		return false
	if owner_body.current_state == owner_body.state_machine.State.ATTACKING:
		return false
	return true

func can_perform_air_attack() -> bool:
	if not owner_body.character_data.can_attack or not owner_body.character_data.can_air_attack:
		return false
	return true

func execute_attack():
	if not can_perform_attack():
		return
	
	var max_count_of_attack = 3
	
	if count_of_attack < max_count_of_attack:
		count_of_attack += 1
	else:
		count_of_attack = 1
	
	if owner_body.debug_helper.console_debug:
		owner_body.debug_helper.log_attack("Normal Attack", count_of_attack)
	
	state_machine.transition_to(owner_body.state_machine.State.ATTACKING)
	
	timers_handler.hide_weapon_timer.stop()
	timers_handler.hide_weapon_timer.start()
	timers_handler.before_attack_timer.start()

func perform_attack():
	if owner_body.stamina_current >= owner_body.character_data.attack_stamina_cost:
		owner_body.stamina_current -= owner_body.character_data.attack_stamina_cost
		owner_body.stamina_regen_timer = owner_body.character_data.stamina_regen_delay
		execute_attack()

func perform_air_attack():
	if not can_perform_air_attack():
		return
	if owner_body.stamina_current >= owner_body.character_data.attack_stamina_cost:
		owner_body.stamina_current -= owner_body.character_data.attack_stamina_cost
		owner_body.stamina_regen_timer = owner_body.character_data.stamina_regen_delay
		execute_attack()

func on_attack_state_enter():
	velocity_before_attack = owner_body.velocity.x
	damage_applied_this_attack = false
	timers_handler.damage_timer.start()

func on_attack_state_exit():
	if owner_body.current_state != owner_body.state_machine.State.KNOCKBACK and owner_body.current_state != owner_body.state_machine.State.DASH_ATTACK:
		pending_knockback_force = Vector2.ZERO

func process_attack_movement():
	if has_nearby_enemy():
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0, owner_body.character_data.attack_movement_friction * owner_body.character_data.enemy_nearby_friction_multiplier)
		return
		
	if owner_body.is_on_floor():
		var attack_force = owner_body.character_data.attack_movement_force * owner_body.character_data.ground_attack_force_multiplier
		if count_of_attack == 3:
			attack_force *= owner_body.character_data.attack_movement_multiplier
		owner_body.velocity.x = get_attack_direction() * attack_force
	else:
		var air_attack_force = owner_body.character_data.attack_movement_force * owner_body.character_data.air_attack_force_multiplier
		owner_body.velocity.x = get_attack_direction() * air_attack_force
	
	if owner_body.is_on_floor():
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0, owner_body.character_data.attack_movement_friction * owner_body.character_data.ground_friction_multiplier)
	else:
		owner_body.velocity.x = move_toward(owner_body.velocity.x, 0, owner_body.character_data.attack_movement_friction * owner_body.character_data.air_friction_multiplier)

func execute_damage_to_entities():
	if not owner_body.character_data.can_take_damage:
		return
		
	if owner_body.current_state == owner_body.state_machine.State.BIG_ATTACK_LANDING:
		apply_big_attack_damage()
	else:
		apply_normal_attack_damage()

func apply_normal_attack_damage():
	if not owner_body.character_data.can_take_damage:
		return
		
	var overlapping_bodies = areas_handler.attack_area.get_overlapping_bodies()
	
	if overlapping_bodies.is_empty():
		return
	
	var damage = 0
	match count_of_attack:
		1:
			damage = owner_body.character_data.attack_1_dmg
		2:
			damage = owner_body.character_data.attack_2_dmg
		3:
			damage = owner_body.character_data.attack_3_dmg
	
	var base_knockback_force = owner_body.character_data.knockback_force
	if count_of_attack == 3:
		base_knockback_force *= owner_body.character_data.knockback_force_multiplier
	
	var attack_dir = get_attack_direction()
	var hit_count = 0
	
	for entity in overlapping_bodies:
		if entity == owner_body:
			continue
		
		hit_count += 1
		
		if owner_body.debug_helper:
			owner_body.debug_helper.log_damage_dealt(entity.name, damage, "Attack " + str(count_of_attack))
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if owner_body.character_data.can_take_knockback:
			var knockback_force = Vector2(
				attack_dir * base_knockback_force,
				owner_body.character_data.jump_velocity * owner_body.character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * owner_body.character_data.knockback_reaction_multiplier * owner_body.character_data.knockback_reaction_force_multiplier,
			owner_body.character_data.jump_velocity * owner_body.character_data.knockback_reaction_jump_multiplier
		)
		
		if owner_body.current_state == owner_body.state_machine.State.ATTACKING:
			pending_knockback_force = reaction_force
		else:
			owner_body.apply_knockback(reaction_force)

func apply_big_attack_damage():
	if not owner_body.character_data.can_take_damage:
		return
		
	var front_bodies = areas_handler.big_attack_area.get_overlapping_bodies()
	var back_bodies = areas_handler.big_attack_area_2.get_overlapping_bodies()
	
	var damage = owner_body.character_data.big_attack_dmg
	var base_knockback_force = owner_body.character_data.knockback_force * owner_body.character_data.knockback_force_multiplier
	var attack_dir = get_attack_direction()
	var hit_count = 0

	for entity in front_bodies:
		if entity == owner_body:
			continue
		hit_count += 1
		
		if owner_body.debug_helper:
			owner_body.debug_helper.log_damage_dealt(entity.name, damage, "Big Attack Front")
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if owner_body.character_data.can_take_knockback:
			var knockback_force = Vector2(
				1 * base_knockback_force * 2.0,
				owner_body.character_data.jump_velocity * owner_body.character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	for entity in back_bodies:
		if entity == owner_body or entity in front_bodies:
			continue
		hit_count += 1
		
		if owner_body.debug_helper:
			owner_body.debug_helper.log_damage_dealt(entity.name, damage, "Big Attack Back")
		
		if entity.has_method("take_damage"):
			entity.take_damage(damage)
		
		if owner_body.character_data.can_take_knockback:
			var knockback_force = Vector2(
				-1 * base_knockback_force * 2.0,
				owner_body.character_data.jump_velocity * owner_body.character_data.knockback_vertical_multiplier
			)
			
			if entity.has_method("apply_knockback"):
				entity.apply_knockback(knockback_force)
	
	if hit_count > 0:
		var reaction_force = Vector2(
			-attack_dir * base_knockback_force * owner_body.character_data.knockback_reaction_multiplier * owner_body.character_data.knockback_reaction_force_multiplier,
			owner_body.character_data.jump_velocity * owner_body.character_data.knockback_reaction_jump_multiplier
		)
		owner_body.apply_knockback(reaction_force)

func apply_dash_attack_damage(body: Node2D):
	if body in dash_attack_damaged_entities:
		return
	
	if not owner_body.character_data.can_take_damage:
		return
	
	dash_attack_damaged_entities.append(body)
	
	var damage = owner_body.character_data.dash_attack_dmg
	var base_knockback_force = owner_body.character_data.knockback_force * owner_body.character_data.knockback_force_multiplier
	var attack_dir = get_attack_direction()
	
	if owner_body.debug_helper:
		owner_body.debug_helper.log_damage_dealt(body.name, damage, "Dash Attack")
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	if owner_body.character_data.can_take_knockback:
		var knockback_force = Vector2(
			attack_dir * base_knockback_force * 1.5,
			owner_body.character_data.jump_velocity * owner_body.character_data.knockback_vertical_multiplier
		)
		
		if body.has_method("apply_knockback"):
			body.apply_knockback(knockback_force)
	
	var reaction_force = Vector2(
		-attack_dir * base_knockback_force * owner_body.character_data.knockback_reaction_multiplier,
		0
	)
	pending_knockback_force = reaction_force

func handle_attack_animation_finished(anim_name: String):
	if owner_body.current_state == owner_body.state_machine.State.ATTACKING:
		if anim_name.begins_with("Attack_ground"):
			if pending_knockback_force.length() > 0:
				owner_body.apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				owner_body.velocity.x = velocity_before_attack
				state_machine.transition_to(owner_body.state_machine.State.IDLE)
		elif anim_name.begins_with("Attack_air"):
			if pending_knockback_force.length() > 0:
				owner_body.apply_knockback(pending_knockback_force)
				pending_knockback_force = Vector2.ZERO
			else:
				state_machine.transition_to(owner_body.state_machine.State.JUMPING)

func update_attack_animations():
	var anim_name = ""
	if owner_body.is_on_floor():
		match count_of_attack:
			1: 
				anim_name = "Attack_ground_1"
				set_weapon_visibility("back")
			2:  
				anim_name = "Attack_ground_2"
				set_weapon_visibility("front")
			3:  
				anim_name = "Attack_ground_3"
				set_weapon_visibility("both")
	else:
		match count_of_attack:
			1: 
				anim_name = "Attack_air_1"
				set_weapon_visibility("back")
			2:  
				anim_name = "Attack_air_2"
				set_weapon_visibility("front")
			3:  
				anim_name = "Attack_air_3"
				set_weapon_visibility("both")
	
	if animation_player.current_animation != anim_name:
		owner_body.play_animation(anim_name)

func get_attack_direction() -> float:
	return -body_node.scale.x

func has_nearby_enemy() -> bool:
	var overlapping_bodies = areas_handler.attack_area.get_overlapping_bodies()
	
	for entity in overlapping_bodies:
		if entity == owner_body:
			continue
		return true
	return false

func set_weapon_visibility(state: String):
	match state:
		"hide":
			body_node.sword_f.visible = false
			body_node.sword_b.visible = false
			body_node.sword_body_2.visible = true
			body_node.sword_body.visible = true
		"front":
			body_node.sword_f.visible = true
			body_node.sword_b.visible = false
			body_node.sword_body_2.visible = true
			body_node.sword_body.visible = false
		"back":
			body_node.sword_f.visible = false
			body_node.sword_b.visible = true
			body_node.sword_body_2.visible = false
			body_node.sword_body.visible = true
		"both":
			body_node.sword_f.visible = true
			body_node.sword_b.visible = true
			body_node.sword_body_2.visible = false
			body_node.sword_body.visible = false

func _on_attack_area_body_entered(_body: Node2D):
	if owner_body.current_state != owner_body.state_machine.State.DASH_ATTACK or _body == owner_body:
		return
	
	apply_dash_attack_damage(_body)

func _on_attack_area_body_exited(_body: Node2D):
	pass

func _on_damage_timer_timeout():
	if not damage_applied_this_attack:
		damage_applied_this_attack = true
		execute_damage_to_entities()

func _on_hide_weapon_timer_timeout():
	set_weapon_visibility("hide")
