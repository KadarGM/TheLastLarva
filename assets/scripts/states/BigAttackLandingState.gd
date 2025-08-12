extends State
class_name BigAttackLandingState

func enter() -> void:
	character.execute_damage_to_entities()
	character.velocity.x = 0

func physics_process(_delta: float) -> void:
	character.velocity.x = 0
	
	if character.animation_player.current_animation == "" or (character.animation_player.current_animation == "Big_attack_landing" and not character.animation_player.is_playing()):
		if character.effective_air_time > character.character_data.stun_after_land_treshold:
			state_machine.transition_to("StunnedState")
		else:
			state_machine.transition_to("IdleState")

func exit() -> void:
	character.timers_handler.hide_weapon_timer.stop()
	character.timers_handler.hide_weapon_timer.start()
	character.big_attack_pending = false

func handle_animation() -> void:
	if character.animation_player.current_animation != "Big_attack_landing":
		character.play_animation("Big_attack_landing")
