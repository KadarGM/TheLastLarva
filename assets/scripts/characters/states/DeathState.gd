extends State
class_name DeathState

var death_timer: float = 2.0
var fade_out: bool = false

func enter() -> void:
	character.velocity.x = 0
	character.death_animation_played = false
	death_timer = 2.0
	fade_out = false
	
	if character.areas_handler:
		if character.areas_handler.damage_area:
			character.areas_handler.damage_area.monitoring = false
			character.areas_handler.damage_area.monitorable = false
		if character.areas_handler.attack_area:
			character.areas_handler.attack_area.monitoring = false
			character.areas_handler.attack_area.monitorable = false
		if character.areas_handler.detection_area:
			character.areas_handler.detection_area.monitoring = false
			character.areas_handler.detection_area.monitorable = false
	
	character.set_collision_layer_value(1, false)
	character.set_collision_layer_value(2, false)
	character.set_collision_mask_value(1, false)
	
	character.play_animation("Death")

func physics_process(delta: float) -> void:
	character.velocity.x = 0
	character.apply_gravity(delta)
	
	if character.animation_player.current_animation != "Death":
		death_timer -= delta
		
		if death_timer <= 1.0 and not fade_out:
			fade_out = true
			var tween = character.create_tween()
			tween.tween_property(character.body_node, "modulate:a", 0.0, 1.0)
			tween.tween_callback(character.queue_free)

func handle_animation() -> void:
	if not character.death_animation_played:
		if character.animation_player.current_animation != "Death":
			character.animation_player.stop()
			character.animation_player.play("Death")
		character.death_animation_played = true
