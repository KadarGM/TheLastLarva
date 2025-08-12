extends State
class_name DeathState

func enter() -> void:
	character.velocity.x = 0
	character.death_animation_played = false
	
	if character.areas_handler and character.areas_handler.damage_area:
		character.areas_handler.damage_area.monitorable = false

func physics_process(_delta: float) -> void:
	character.velocity.x = 0

func handle_animation() -> void:
	if not character.death_animation_played and character.animation_player.current_animation != "Death":
		character.animation_player.stop()
		character.animation_player.play("Death")
		character.death_animation_played = true
