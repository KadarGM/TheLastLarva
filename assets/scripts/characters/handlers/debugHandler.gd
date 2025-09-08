extends CanvasLayer
class_name DebugHelper

@export var character: CharacterManager
@export var state_machine: StateMachine
var enabled: bool = true
var console_debug: bool = false
var ui_debug: bool = true

var debug_info: bool = true
var states: bool = true
var combat: bool = true
var movement: bool = true
var jump_controller: bool = true
var wall_check: bool = true
var areas: bool = true
var timers: bool = true

@export var debug_holder: DebugPartsHandler

@onready var enable_debug_button: CheckBox = $VBoxContainer/Buttons/EnableDebugButton
@onready var debug_info_button: CheckBox = $VBoxContainer/Buttons/DebugInfoButton
@onready var states_button: CheckBox = $VBoxContainer/Buttons/StatesButton
@onready var combat_button: CheckBox = $VBoxContainer/Buttons/CombatButton
@onready var movement_button: CheckBox = $VBoxContainer/Buttons/MovementButton
@onready var jump_controller_button: CheckBox = $VBoxContainer/Buttons/JumpControllerButton
@onready var rays_button: CheckBox = $VBoxContainer/Buttons/RaysButton
@onready var areas_button: CheckBox = $VBoxContainer/Buttons/AreasButton
@onready var timers_button: CheckBox = $VBoxContainer/Buttons/TimersButton
@onready var console_debug_button = $VBoxContainer/Buttons/ConsoleDebugButton

var previous_state: String = ""
var previous_animation: String = ""
var previous_velocity: Vector2 = Vector2.ZERO
var previous_big_jump_charged: bool = false
var previous_can_dash: bool = true
var previous_can_big_jump: bool = true
var previous_can_wall_jump: bool = true
var previous_health: int = 0
var previous_stamina: float = 0.0
var previous_invulnerability: bool = false

func _ready():
	if not enabled:
		return
		
	if character:
		if character.stats_controller:
			previous_health = character.stats_controller.get_health()
			previous_stamina = character.stats_controller.get_stamina()
		
		if state_machine:
			state_machine.state_changed.connect(_on_state_changed)
	
	section_visibility()

func section_visibility() -> void:
	debug_holder.visible = enable_debug_button.button_pressed
	console_debug = console_debug_button.button_pressed
	
	debug_info_button.visible = enable_debug_button.button_pressed
	states_button.visible = enable_debug_button.button_pressed
	combat_button.visible = enable_debug_button.button_pressed
	movement_button.visible = enable_debug_button.button_pressed
	jump_controller_button.visible = enable_debug_button.button_pressed
	rays_button.visible = enable_debug_button.button_pressed
	areas_button.visible = enable_debug_button.button_pressed
	timers_button.visible = enable_debug_button.button_pressed
	
	debug_holder.debug_info_holder.visible = debug_info_button.button_pressed
	debug_holder.states_holder.visible = states_button.button_pressed
	debug_holder.combat_holder.visible = combat_button.button_pressed
	debug_holder.movement_holder.visible = movement_button.button_pressed
	debug_holder.jump_controller_holder.visible = jump_controller_button.button_pressed
	debug_holder.rays_holder.visible = rays_button.button_pressed
	debug_holder.areas_holder.visible = areas_button.button_pressed
	debug_holder.timers_holder.visible = timers_button.button_pressed

func _process(_delta: float) -> void:
	if not enabled or not character:
		return
	
	if ui_debug and debug_holder:
		section_visibility()
		update_ui_debug()
	
	if console_debug:
		check_changes()

func update_ui_debug() -> void:
	if debug_holder.state_text:
		debug_holder.state_text.text = state_machine.get_current_state_name() if state_machine else "NONE"
	
	if debug_holder.previous_state_text:
		debug_holder.previous_state_text.text = character.previous_state if character else "NONE"
	
	if debug_holder.animation_text and character.animation_player:
		debug_holder.animation_text.text = character.animation_player.current_animation
	
	if debug_holder.velocity_text:
		debug_holder.velocity_text.text = str(character.velocity)
	
	if debug_holder.on_floor_text:
		debug_holder.on_floor_text.text = str(character.is_on_floor())
	
	if character.stats_controller:
		if debug_holder.health_text:
			debug_holder.health_text.text = str(character.stats_controller.get_health()) + "/" + str(character.stats_controller.get_max_health())
		
		if debug_holder.stamina_text:
			debug_holder.stamina_text.text = str(int(character.stamina_current)) + "/" + str(int(character.stats_controller.get_max_stamina()))
		
		if debug_holder.stamina_regen_timer_text:
			debug_holder.stamina_regen_timer_text.text = str("%.2f" % character.stamina_regen_timer)
	
	if debug_holder.big_jump_charged_text:
		debug_holder.big_jump_charged_text.text = str(character.big_jump_charged)
	
	if debug_holder.can_big_jump_text:
		debug_holder.can_big_jump_text.text = str(character.can_big_jump)
	
	if debug_holder.can_dash_text:
		debug_holder.can_dash_text.text = str(character.can_dash)
	
	if debug_holder.can_wall_jump_text:
		debug_holder.can_wall_jump_text.text = str(character.can_wall_jump)
	
	if debug_holder.has_wall_jumped_text:
		debug_holder.has_wall_jumped_text.text = "N/A"
	
	if debug_holder.was_on_wall_text:
		debug_holder.was_on_wall_text.text = str(character.was_on_wall)
	
	if debug_holder.invulnerable_text:
		debug_holder.invulnerable_text.text = str(character.invulnerability_temp)
	
	if debug_holder.death_animation_played_text:
		debug_holder.death_animation_played_text.text = str(character.death_animation_played)
	
	#if debug_holder.attack_count_text:
		#debug_holder.attack_count_text.text = str(character.attack_count)
	
	if debug_holder.damage_applied_text:
		debug_holder.damage_applied_text.text = str(character.damage_applied_this_attack)
	
	if debug_holder.velocity_before_attack_text:
		debug_holder.velocity_before_attack_text.text = str("%.1f" % character.velocity_before_attack)
	
	if debug_holder.pending_knockback_text:
		debug_holder.pending_knockback_text.text = str(character.pending_knockback_force)
	
	if debug_holder.dash_attack_entities_hit_text:
		debug_holder.dash_attack_entities_hit_text.text = str(character.dash_attack_damaged_entities.size())
	
	if debug_holder.air_time_text:
		debug_holder.air_time_text.text = str("%.2f" % character.air_time)
	
	if debug_holder.effective_air_time_text:
		debug_holder.effective_air_time_text.text = str("%.2f" % character.effective_air_time)
	
	if debug_holder.big_attack_pending_text:
		debug_holder.big_attack_pending_text.text = str(character.big_attack_pending)
	
	if debug_holder.is_high_big_attack_text:
		debug_holder.is_high_big_attack_text.text = str(character.is_high_big_attack)
	
	if debug_holder.big_jump_direction_text:
		debug_holder.big_jump_direction_text.text = str(character.big_jump_direction)
	
	if debug_holder.dash_attack_direction_text:
		var dash_state = state_machine.states.get("DashAttackState") if state_machine else null
		if dash_state and state_machine.current_state == dash_state:
			debug_holder.dash_attack_direction_text.text = str(dash_state.dash_direction)
		else:
			debug_holder.dash_attack_direction_text.text = "0"
	
	if debug_holder.knockback_velocity_text:
		debug_holder.knockback_velocity_text.text = str(character.knockback_velocity)
	
	if debug_holder.knockback_timer_text:
		debug_holder.knockback_timer_text.text = str("%.2f" % character.knockback_timer)
	
	if debug_holder.jump_count_text:
		debug_holder.jump_count_text.text = str(character.jump_count)
	
	if debug_holder.has_double_jump_text:
		debug_holder.has_double_jump_text.text = str(character.has_double_jump)
	
	if debug_holder.has_triple_jump_text:
		debug_holder.has_triple_jump_text.text = str(character.has_triple_jump)
	
	if debug_holder.is_jump_held_text:
		debug_holder.is_jump_held_text.text = str(Input.is_action_pressed("W_jump"))
	
	if debug_holder.is_double_jump_held_text:
		debug_holder.is_double_jump_held_text.text = str(character.is_double_jump_held)
	
	if debug_holder.is_triple_jump_held_text:
		debug_holder.is_triple_jump_held_text.text = str(character.is_triple_jump_held)
	
	if character.ray_casts_handler:
		if debug_holder.left_wall_text:
			debug_holder.left_wall_text.text = str(character.ray_casts_handler.left_wall_ray.is_colliding())
		
		if debug_holder.right_wall_text:
			debug_holder.right_wall_text.text = str(character.ray_casts_handler.right_wall_ray.is_colliding())
		
		if debug_holder.ceiling_text:
			debug_holder.ceiling_text.text = str(character.ray_casts_handler.ceiling_ray.is_colliding())
		
		if debug_holder.ceiling_2_text:
			debug_holder.ceiling_2_text.text = str(character.ray_casts_handler.ceiling_ray_2.is_colliding())
		
		if debug_holder.ceiling_3_text:
			debug_holder.ceiling_3_text.text = str(character.ray_casts_handler.ceiling_ray_3.is_colliding())
		
		if debug_holder.ground_check_text:
			debug_holder.ground_check_text.text = str(character.ray_casts_handler.ground_check_ray.is_colliding())
		
		if debug_holder.near_ground_text:
			debug_holder.near_ground_text.text = str(character.ray_casts_handler.near_ground_ray.is_colliding())
		
		if debug_holder.near_ground_2_text:
			debug_holder.near_ground_2_text.text = str(character.ray_casts_handler.near_ground_ray_2.is_colliding())
		
		if debug_holder.near_ground_3_text:
			debug_holder.near_ground_3_text.text = str(character.ray_casts_handler.near_ground_ray_3.is_colliding())
	
	if character.timers_handler:
		if debug_holder.big_jump_timer_text:
			debug_holder.big_jump_timer_text.text = str("%.2f" % character.timers_handler.big_jump_timer.time_left)
		
		if debug_holder.big_jump_cd_text:
			debug_holder.big_jump_cd_text.text = str("%.2f" % character.timers_handler.big_jump_cooldown_timer.time_left)
		
		if debug_holder.dash_timer_text:
			debug_holder.dash_timer_text.text = str("%.2f" % character.timers_handler.dash_timer.time_left)
		
		if debug_holder.dash_cd_text:
			debug_holder.dash_cd_text.text = str("%.2f" % character.timers_handler.dash_cooldown_timer.time_left)
		
		if debug_holder.attack_timer_text:
			debug_holder.attack_timer_text.text = str("%.2f" % character.timers_handler.before_attack_timer.time_left)
		
		#if debug_holder.attack_cd_text:
			#debug_holder.attack_cd_text.text = str("%.2f" % character.timers_handler.attack_cooldown_timer.time_left)
		
		if debug_holder.stun_timer_text:
			debug_holder.stun_timer_text.text = str("%.2f" % character.timers_handler.stun_timer.time_left)
		
		if debug_holder.hide_weapon_text:
			debug_holder.hide_weapon_text.text = str("%.2f" % character.timers_handler.hide_weapon_timer.time_left)
		
		if debug_holder.damage_timer_text:
			debug_holder.damage_timer_text.text = str("%.2f" % character.timers_handler.damage_timer.time_left)
		
		if debug_holder.invulnerability_text:
			debug_holder.invulnerability_text.text = str("%.2f" % character.timers_handler.invulnerability_timer.time_left)
		
		if debug_holder.wall_jump_control_text:
			debug_holder.wall_jump_control_text.text = str("%.2f" % character.timers_handler.wall_jump_control_timer.time_left)
	
	if character.areas_handler:
		if character.areas_handler.attack_area and debug_holder.attack_area_bodies_text:
			if character.areas_handler.attack_area.monitoring:
				debug_holder.attack_area_bodies_text.text = str(character.areas_handler.attack_area.get_overlapping_bodies().size())
			else:
				debug_holder.attack_area_bodies_text.text = "Off"
		
		if character.areas_handler.damage_area:
			if debug_holder.damage_area_bodies_text:
				if character.areas_handler.damage_area.monitoring:
					debug_holder.damage_area_bodies_text.text = str(character.areas_handler.damage_area.get_overlapping_bodies().size())
				else:
					debug_holder.damage_area_bodies_text.text = "Off"
			
			if debug_holder.damage_area_monitorable_text:
				debug_holder.damage_area_monitorable_text.text = str(character.areas_handler.damage_area.monitorable)
		
		if character.areas_handler.big_attack_area and debug_holder.big_attack_area_bodies_text:
			if character.areas_handler.big_attack_area.monitoring:
				debug_holder.big_attack_area_bodies_text.text = str(character.areas_handler.big_attack_area.get_overlapping_bodies().size())
			else:
				debug_holder.big_attack_area_bodies_text.text = "Off"
		
		if character.areas_handler.big_attack_area_2 and debug_holder.big_attack_area_2_bodies_text:
			if character.areas_handler.big_attack_area_2.monitoring:
				debug_holder.big_attack_area_2_bodies_text.text = str(character.areas_handler.big_attack_area_2.get_overlapping_bodies().size())
			else:
				debug_holder.big_attack_area_2_bodies_text.text = "Off"

func check_changes() -> void:
	var current_state = state_machine.get_current_state_name() if state_machine else ""
	if current_state != previous_state:
		log_state_change(previous_state, current_state)
		previous_state = current_state
	
	if character.animation_player and character.animation_player.current_animation != previous_animation:
		log_animation_change(previous_animation, character.animation_player.current_animation)
		previous_animation = character.animation_player.current_animation
	
	if character.velocity != previous_velocity:
		if abs(character.velocity.x - previous_velocity.x) > 100 or abs(character.velocity.y - previous_velocity.y) > 100:
			log_velocity_change(previous_velocity, character.velocity)
			previous_velocity = character.velocity
	
	if character.big_jump_charged != previous_big_jump_charged:
		log_big_jump_charged_change(previous_big_jump_charged, character.big_jump_charged)
		previous_big_jump_charged = character.big_jump_charged
	
	if character.can_dash != previous_can_dash:
		log_can_dash_change(previous_can_dash, character.can_dash)
		previous_can_dash = character.can_dash
	
	if character.can_big_jump != previous_can_big_jump:
		log_can_big_jump_change(previous_can_big_jump, character.can_big_jump)
		previous_can_big_jump = character.can_big_jump
	
	if character.can_wall_jump != previous_can_wall_jump:
		log_can_wall_jump_change(previous_can_wall_jump, character.can_wall_jump)
		previous_can_wall_jump = character.can_wall_jump
	
	if character.stats_controller:
		var current_health = character.stats_controller.get_health()
		if current_health != previous_health:
			log_health_change(previous_health, current_health)
			previous_health = current_health
		
		var current_stamina = character.stamina_current
		if abs(current_stamina - previous_stamina) > 10:
			log_stamina_change(previous_stamina, current_stamina)
			previous_stamina = current_stamina
	
	if character.invulnerability_temp != previous_invulnerability:
		log_invulnerability_change(previous_invulnerability, character.invulnerability_temp)
		previous_invulnerability = character.invulnerability_temp

func _on_state_changed(old_state: State, new_state: State) -> void:
	if console_debug:
		var old_name: String = str(old_state.name) if old_state else "None"
		var new_name: String = str(new_state.name) if new_state else "None"
		print("[DEBUG] State changed: ", old_name, " -> ", new_name)

func log_state_change(old_state: String, new_state: String) -> void:
	print("[DEBUG] State transition: ", old_state, " -> ", new_state)

func log_animation_change(old_anim: String, new_anim: String) -> void:
	if new_anim != "":
		print("[DEBUG] Animation changed: ", old_anim, " -> ", new_anim)

func log_velocity_change(old_vel: Vector2, new_vel: Vector2) -> void:
	print("[DEBUG] Velocity changed: ", old_vel, " -> ", new_vel)

func log_big_jump_charged_change(_old_val: bool, new_val: bool) -> void:
	if new_val:
		print("[DEBUG] Big jump CHARGED!")
	else:
		print("[DEBUG] Big jump charge cancelled")

func log_can_dash_change(_old_val: bool, new_val: bool) -> void:
	if new_val:
		print("[DEBUG] Dash available")
	else:
		print("[DEBUG] Dash on cooldown")

func log_can_big_jump_change(_old_val: bool, new_val: bool) -> void:
	if new_val:
		print("[DEBUG] Big jump available")
	else:
		print("[DEBUG] Big jump on cooldown")

func log_can_wall_jump_change(_old_val: bool, new_val: bool) -> void:
	if new_val:
		print("[DEBUG] Wall jump available")
	else:
		print("[DEBUG] Wall jump used")

func log_health_change(old_health: int, new_health: int) -> void:
	var damage = old_health - new_health
	if damage > 0:
		print("[DEBUG] Damage taken: ", damage, " - Health: ", old_health, " -> ", new_health)
	else:
		print("[DEBUG] Health restored: ", abs(damage), " - Health: ", old_health, " -> ", new_health)

func log_stamina_change(old_stamina: float, new_stamina: float) -> void:
	var cost = old_stamina - new_stamina
	if cost > 0:
		print("[DEBUG] Stamina used: ", int(cost), " - Stamina: ", int(old_stamina), " -> ", int(new_stamina))
	else:
		print("[DEBUG] Stamina regenerated - Stamina: ", int(old_stamina), " -> ", int(new_stamina))

func log_invulnerability_change(_old_val: bool, new_val: bool) -> void:
	if new_val:
		var duration = 0.0
		if character.timers_handler and character.timers_handler.invulnerability_timer:
			duration = character.timers_handler.invulnerability_timer.wait_time
		print("[DEBUG] Invulnerability activated for ", duration, " seconds")
	else:
		print("[DEBUG] Invulnerability deactivated")

func log_attack(attack_type: String, count: int = 0) -> void:
	if count > 0:
		print("[DEBUG] Performing attack ", count, " of 3 - Type: ", attack_type)
	else:
		print("[DEBUG] Performing ", attack_type)

func log_jump(jump_type: String) -> void:
	print("[DEBUG] Executing ", jump_type)

func log_dash(dash_type: String = "normal") -> void:
	if dash_type == "charged":
		print("[DEBUG] Performing charged dash")
	else:
		print("[DEBUG] Performing dash")

func log_knockback(force: Vector2, source: String = "") -> void:
	if source != "":
		print("[DEBUG] Knockback applied from ", source, " - Force: ", force)
	else:
		print("[DEBUG] Knockback applied - Force: ", force)

func log_damage_dealt(target: String, damage: int, attack_type: String = "") -> void:
	if attack_type != "":
		print("[DEBUG] ", attack_type, " hit ", target, " - Damage: ", damage)
	else:
		print("[DEBUG] Hit ", target, " - Damage: ", damage)

func log_wall_interaction(interaction_type: String) -> void:
	print("[DEBUG] Wall interaction: ", interaction_type)

func log_ability_blocked(ability: String, reason: String) -> void:
	print("[DEBUG] ", ability, " blocked - Reason: ", reason)

func log_combat_state(state: String, details: String = "") -> void:
	if details != "":
		print("[DEBUG] Combat: ", state, " - ", details)
	else:
		print("[DEBUG] Combat: ", state)
