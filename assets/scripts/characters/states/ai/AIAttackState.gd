extends State
class_name AIAttackState

var attack_timer: float = 0.0
var combo_count: int = 0
var combo_window: float = 0.0
var has_attacked: bool = false

func enter() -> void:
	attack_timer = 0.0
	has_attacked = false
	character.velocity.x = 0

func exit() -> void:
	combo_count = 0

func physics_process(delta: float) -> void:
	character.apply_gravity(delta)
	
	if attack_timer > 0:
		attack_timer -= delta
	
	if combo_window > 0:
		combo_window -= delta
		if combo_window <= 0:
			combo_count = 0
	
	var ai_controller = character.controller as AIController
	if not ai_controller:
		state_machine.transition_to("PatrolState")
		return
	
	if not ai_controller.player_in_attack_range:
		if ai_controller.player_in_detection_zone and ai_controller.can_see_player:
			state_machine.transition_to("ChaseState")
		else:
			state_machine.transition_to("SearchState")
		return
	
	if attack_timer <= 0 and not has_attacked:
		perform_attack()
	
	if ai_controller.chase_direction != 0:
		character.velocity.x = ai_controller.chase_direction * character.character_data.speed * 0.2
	else:
		character.velocity.x = 0

func perform_attack() -> void:
	if character.timers_handler.before_attack_timer.is_stopped():
		character.attack_count = combo_count + 1
		if character.attack_count > 3:
			character.attack_count = 1
			combo_count = 0
		else:
			combo_count = character.attack_count
		
		character.perform_attack()
		has_attacked = true
		attack_timer = character.character_data.attack_cooldown
		combo_window = 0.8
		
		await character.get_tree().create_timer(0.5).timeout
		has_attacked = false

func handle_animation() -> void:
	if not has_attacked:
		character.play_animation("Idle")
