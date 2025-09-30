extends Control
class_name TimersHandler

@export var character_manager: CharacterManager

@export var between_states_timer: Timer
@export var emergency_timer: Timer
@export var big_jump_timer: Timer
@export var big_jump_cooldown_timer: Timer
@export var hide_weapon_timer: Timer
@export var dash_timer: Timer
@export var stun_timer: Timer
@export var dash_cooldown_timer: Timer
@export var dash_attack_cooldown_timer: Timer
@export var wall_jump_control_timer: Timer
@export var attack_cooldown_timer: Timer
@export var damage_timer: Timer
@export var before_attack_timer: Timer
@export var invulnerability_timer: Timer

func setup_timers() -> void:
	if hide_weapon_timer:
		hide_weapon_timer.wait_time = character_manager.character_data.hide_weapon_time
		hide_weapon_timer.one_shot = true
		hide_weapon_timer.timeout.connect(_on_hide_weapon_timer_timeout)
	
	if dash_timer:
		dash_timer.wait_time = character_manager.character_data.dash_duration
		dash_timer.one_shot = true
		dash_timer.timeout.connect(_on_dash_timer_timeout)
	
	if big_jump_timer:
		big_jump_timer.wait_time = character_manager.character_data.big_jump_charge_time
		big_jump_timer.one_shot = true
		big_jump_timer.timeout.connect(_on_big_jump_timer_timeout)
	
	if stun_timer:
		stun_timer.wait_time = character_manager.character_data.stun_time
		stun_timer.one_shot = true
		stun_timer.timeout.connect(_on_stun_timer_timeout)
	
	if dash_cooldown_timer:
		dash_cooldown_timer.wait_time = character_manager.character_data.dash_cooldown_time
		dash_cooldown_timer.one_shot = true
		dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timer_timeout)
	
	if dash_attack_cooldown_timer:
		dash_attack_cooldown_timer.wait_time = character_manager.character_data.dash_attack_cooldown
		dash_attack_cooldown_timer.one_shot = true
		dash_attack_cooldown_timer.timeout.connect(_on_dash_attack_cooldown_timer_timeout)
	
	if damage_timer:
		damage_timer.wait_time = character_manager.character_data.damage_delay
		damage_timer.one_shot = true
		damage_timer.timeout.connect(_on_damage_timer_timeout)
	
	if invulnerability_timer:
		invulnerability_timer.wait_time = character_manager.character_data.invulnerability_after_damage
		invulnerability_timer.one_shot = true
		invulnerability_timer.timeout.connect(_on_invulnerability_timer_timeout)
	
	if wall_jump_control_timer:
		wall_jump_control_timer.wait_time = character_manager.character_data.wall_jump_control_delay
		wall_jump_control_timer.one_shot = true
		wall_jump_control_timer.timeout.connect(_on_wall_jump_control_timer_timeout)
	
	if before_attack_timer:
		before_attack_timer.wait_time = character_manager.character_data.attack_cooldown
		before_attack_timer.one_shot = true
		before_attack_timer.timeout.connect(_on_before_attack_timer_timeout)
	
	if big_jump_cooldown_timer:
		big_jump_cooldown_timer.wait_time = character_manager.character_data.big_jump_cooldown
		big_jump_cooldown_timer.one_shot = true
		big_jump_cooldown_timer.timeout.connect(_on_big_jump_cooldown_timer_timeout)
	
	if attack_cooldown_timer:
		attack_cooldown_timer.wait_time = character_manager.character_data.attack_combo_reset_time
		attack_cooldown_timer.one_shot = true
		attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)

func _on_hide_weapon_timer_timeout() -> void:
	character_manager.set_weapon_visibility("hide")
	character_manager.attack_count = 0

func _on_dash_timer_timeout() -> void:
	pass

func _on_big_jump_timer_timeout() -> void:
	character_manager.big_jump_charged = true

func _on_stun_timer_timeout() -> void:
	if character_manager.state_machine.current_state and character_manager.state_machine.current_state.name == "StunnedState":
		character_manager.state_machine.transition_to("IdleState")

func _on_dash_cooldown_timer_timeout() -> void:
	character_manager.can_dash = true

func _on_dash_attack_cooldown_timer_timeout() -> void:
	pass

func _on_damage_timer_timeout() -> void:
	if character_manager.state_machine.current_state and character_manager.state_machine.current_state.name == "AttackingState":
		var attack_state = character_manager.state_machine.current_state as AttackingState
		if attack_state:
			attack_state.apply_damage()

func _on_invulnerability_timer_timeout() -> void:
	character_manager.invulnerability_temp = false

func _on_wall_jump_control_timer_timeout() -> void:
	pass

func _on_before_attack_timer_timeout() -> void:
	pass

func _on_big_jump_cooldown_timer_timeout() -> void:
	character_manager.can_big_jump = true

func _on_attack_cooldown_timer_timeout() -> void:
	character_manager.attack_count = 0
	character_manager.set_weapon_visibility("hide")
