extends State
class_name BigAttackLandingState

var damage_applied: bool = false
var animation_finished: bool = false

func enter() -> void:
	character.velocity = Vector2.ZERO
	character.big_attack_pending = false
	damage_applied = false
	animation_finished = false
	
	character.play_animation("Big_attack_landing")
	
	apply_big_attack_damage()

func exit() -> void:
	character.set_weapon_visibility("hide")

func physics_process(_delta: float) -> void:
	character.velocity = Vector2.ZERO
	
	if animation_finished:
		if character.effective_air_time > character.character_data.stun_after_land_treshold:
			state_machine.transition_to("StunnedState")
		else:
			state_machine.transition_to("IdleState")

func apply_big_attack_damage() -> void:
	if damage_applied:
		return
	
	damage_applied = true
	
	var damage_area = null
	if character.is_high_big_attack:
		damage_area = character.areas_handler.big_attack_area_2
	else:
		damage_area = character.areas_handler.big_attack_area
	
	if not damage_area:
		return
	
	var bodies = damage_area.get_overlapping_bodies()
	for body in bodies:
		if body == character:
			continue
		
		if body.is_in_group("dead"):
			continue
		
		if body.has_method("state_machine") and body.state_machine:
			if body.state_machine.current_state and body.state_machine.current_state.name == "DeathState":
				continue
		
		if body.has_method("take_damage"):
			body.take_damage(character.character_data.big_attack_dmg, character.global_position)
		
		if body.has_method("apply_knockback"):
			if body.has_method("state_machine") and body.state_machine:
				if body.state_machine.current_state and body.state_machine.current_state.name == "DeathState":
					continue
			
			var direction = (body.global_position - character.global_position).normalized()
			var knockback = Vector2(
				direction.x * character.character_data.knockback_force * 2.0,
				-abs(character.character_data.jump_velocity) * 0.5
			)
			body.apply_knockback(knockback)

func on_animation_finished() -> void:
	animation_finished = true

func handle_animation() -> void:
	pass
