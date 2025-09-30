extends State
class_name DeathState

var death_timer: float = 0.0
var fade_out: bool = false
var sink_amount: float = 0.0

func enter() -> void:
	character.velocity.x = 0
	character.death_animation_played = false
	death_timer = character.character_data.death_disappear_delay
	fade_out = false
	sink_amount = 0.0
	
	if not character.is_in_group("dead"):
		character.add_to_group("dead")
	
	character.invulnerability_temp = true
	
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
	
	character.set_collision_layer_value(2, false)
	character.set_collision_mask_value(2, false)
	
	character.play_animation("Death")

func exit() -> void:
	pass

func physics_process(delta: float) -> void:
	character.velocity.x = 0
	character.apply_gravity(delta)
	
	if character.character_data.death_sink_into_ground and character.is_on_floor():
		sink_amount += character.character_data.death_sink_speed * delta
		character.position.y += character.character_data.death_sink_speed * delta
	
	if character.animation_player.current_animation != "Death" or character.death_animation_played:
		if character.character_data.death_disappear:
			death_timer -= delta
			
			if death_timer <= character.character_data.death_fade_duration and not fade_out:
				fade_out = true
				var tween = character.create_tween()
				tween.tween_property(character.body_node, "modulate:a", 0.0, character.character_data.death_fade_duration)
				tween.tween_callback(character.queue_free)

func handle_animation() -> void:
	if not character.death_animation_played:
		if character.animation_player.current_animation != "Death":
			character.animation_player.stop()
			character.animation_player.play("Death")
		character.death_animation_played = true
