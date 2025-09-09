extends Resource
class_name CharacterData

@export_group("Health & Stamina Options")
@export var health_max: int = 1000
@export var stamina_max: float = 10000.0
@export var stamina_regen_rate: float = 100.0
@export var stamina_regen_delay: float = 1.0

@export_group("Physics Options")
@export var weight: float = 100.0

@export_group("Jumps Options")
@export var can_jump: bool = true
@export var can_double_jump: bool = false
@export var can_triple_jump: bool = false
@export var can_wall_jump: bool = false
@export var can_big_jump: bool = false
@export var can_wall_big_jump: bool = false

@export_subgroup("Normal Jump")
@export var jump_velocity: float = -450.0
@export var jump_release_multiplier: float = 0.5

@export_subgroup("Double Jump")
@export var double_jump_multiplier: float = 0.9
@export var double_jump_stamina_cost: float = 0.0

@export_subgroup("Triple Jump")
@export var triple_jump_multiplier: float = 0.8
@export var triple_jump_stamina_cost: float = 300.0

@export_subgroup("Wall Jump")
@export var wall_jump_force: float = 250.0
@export var wall_jump_control_delay: float = 0.15
@export var wall_jump_away_multiplier: float = 0.5

@export_subgroup("Big Jump")
@export var big_jump_charge_time: float = 3.0
@export var big_jump_multiplier: float = 2.0
@export var big_jump_dash_multiplier: float = 3.0
@export var big_jump_horizontal_speed: float = 1500.0
@export var big_jump_vertical_speed: float = 1500.0
@export var big_jump_duration: float = 1.0
@export var big_jump_stamina_drain_rate: float = 1000.0
@export var big_jump_cooldown: float = 2.0
@export var big_jump_stamina_cost: float = 200.0
@export var big_jump_cooldown_after_use: float = 1.0

@export_group("Parry & Block Options")
@export var can_parry: bool = true
@export var can_block: bool = true

@export_subgroup("Parry Settings")
@export var parry_window_duration: float = 0.5
@export var parry_stamina_cost: float = 100.0
@export var parry_stun_duration: float = 0.8
@export var parry_fail_cooldown: float = 1.0
@export var parry_invulnerability_duration: float = 0.5
@export var parry_knockback_force: float = 300.0
@export var parry_restores_stamina: bool = true
@export var parry_stamina_restore: float = 200.0
@export var parry_heals: bool = false
@export var parry_heal_amount: int = 50

@export_subgroup("Block Settings")
@export var block_stamina_drain_rate: float = 200.0
@export var block_hit_stamina_cost: float = 150.0
@export var block_damage_reduction: float = 0.3
@export var block_knockback_force: float = 100.0

@export_group("Combat Options")
@export var invulnerability: bool = false
@export var can_attack: bool = true
@export var can_air_attack: bool = false
@export var can_big_attack: bool = false
@export var can_dash_attack: bool = false
@export var can_apply_knockback: bool = true
@export var can_receive_knockback: bool = true
@export var can_take_damage: bool = true
@export var can_get_damage: bool = true
@export var poise: float = 0.0
@export var stun_on_hit_base: float = 0.3
@export var stun_on_hit_min: float = 0.1

@export_subgroup("Normal Attack")
@export var attack_cooldown: float = 0.35
@export var attack_area_radius: float = 150.0
@export var attack_stamina_cost: float = 150.0
@export var attack_combo_reset_time: float = 1.3

@export_subgroup("Big Attack")
@export var big_attack_air_friction: float = 0.1
@export var big_attack_distance_treshold: float = 200.0
@export var big_attack_stamina_cost: float = 500.0

@export_subgroup("Dash Attack")
@export var dash_attack_stamina_drain_rate: float = 2000.0
@export var dash_attack_cooldown: float = 1.0

@export_subgroup("Damage")
@export var attack_1_dmg: int = 30
@export var attack_2_dmg: int = 30
@export var attack_3_dmg: int = 40
@export var big_attack_dmg: int = 80
@export var dash_attack_dmg: int = 60
@export var damage_stamina_cost: float = 200.0

@export_subgroup("Combat Movement")
@export var ground_friction_multiplier: float = 0.8
@export var air_friction_multiplier: float = 0.4
@export var enemy_nearby_friction_multiplier: float = 2.0

@export_subgroup("Combat Basic")
@export var hide_weapon_time: float = 1.4
@export var damage_delay: float = 0.2
@export var invulnerability_after_damage: float = 1.2

@export_group("Knockback Given (Outgoing)")
@export var outgoing_knockback_force: float = 150.0
@export var outgoing_knockback_horizontal_multiplier: float = 3.0
@export var outgoing_knockback_vertical_multiplier: float = 0.3
@export var outgoing_knockback_multiplier_combo3: float = 1.1

@export_group("Knockback Self Reaction")
@export var self_knockback_multiplier: float = 0.3
@export var self_knockback_vertical_multiplier: float = 0.5
@export var self_knockback_down_horizontal: float = 0.5
@export var self_knockback_down_vertical: float = 2.0
@export var self_knockback_up_horizontal: float = 0.5
@export var self_knockback_up_vertical: float = 0.5
@export var self_knockback_forward_horizontal: float = 1.0
@export var self_knockback_forward_vertical: float = 0.3
@export var self_knockback_ground_horizontal: float = 1.0
@export var self_knockback_ground_vertical: float = 0.3
@export var self_knockback_hit_multiplier: float = 0.2
@export var self_knockback_max_force: float = 5000.0

@export_group("Knockback Received (Incoming)")
@export var incoming_knockback_duration: float = 0.1
@export var incoming_knockback_friction: float = 30.0
@export var incoming_damage_knockback_force: float = 300.0
@export var incoming_knockback_immunity_time: float = 0.2

@export_group("Death Options")
@export var death_disappear: bool = true
@export var death_disappear_delay: float = 2.0
@export var death_fade_duration: float = 1.0
@export var death_sink_into_ground: bool = false
@export var death_sink_speed: float = 50.0

@export_group("Movement Options")
@export var can_walk: bool = true
@export var can_wall_slide: bool = false
@export var can_dash: bool = false
@export var can_be_stunned: bool = true

@export_subgroup("Basic Movement")
@export var speed: float = 600.0
@export var air_movement_friction: float = 0.1

@export_subgroup("Air Time & Stun")
@export var stun_after_land_treshold: float = 0.8
@export var stun_time: float = 0.5
@export var landing_multiplier: float = 2.0
@export var air_time_initial: float = 0.01

@export_subgroup("Wall Movement")
@export var wall_slide_gravity_multiplier: float = 0.5
@export var wall_slide_initial_velocity_divisor: float = 1000.0
@export var wall_slide_max_speed: float = 300.0
@export var wall_jump_vertical_multiplier: float = 0.7
@export var wall_jump_away_vertical_multiplier: float = 0.2
@export var wall_jump_away_force_multiplier: float = 0.8

@export_subgroup("Dash")
@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.2
@export var dash_cooldown_time: float = 0.7
@export var dash_stamina_cost: float = 100.0

@export_group("AI Options")
@export var can_chase: bool = false
@export var can_patrol: bool = false
@export var ai_enabled: bool = false
@export var ai_can_strafe: bool = false
@export var ai_can_retreat: bool = false
@export var ai_can_flank: bool = false
@export var ai_can_dash: bool = false

@export_subgroup("AI Detection")
@export var ai_detection_range: float = 600.0
@export var ai_attack_range: float = 50.0
@export var ai_vision_cone_angle: float = 120.0
@export var ai_lose_sight_time: float = 2.0

@export_subgroup("AI Combat")
@export var ai_attack_distance_multiplier: float = 0.7
@export var ai_combo_chance: float = 0.6
@export var ai_combo_window: float = 0.8
@export var ai_combo_cooldown_multiplier: float = 2.0
@export var ai_dodge_chance: float = 0.3
@export var ai_block_chance: float = 0.2
@export var ai_reaction_time: float = 0.2
@export var ai_prediction_update_time: float = 0.1
@export var ai_predict_player_movement: bool = true

@export_subgroup("AI Movement")
@export var ai_patrol_speed_multiplier: float = 0.5
@export var ai_chase_speed_multiplier: float = 1.0
@export var ai_search_speed_multiplier: float = 0.6
@export var ai_strafe_speed_multiplier: float = 0.7
@export var ai_flee_health_threshold: float = 0.2
@export var ai_flee_health_threshold_recovery: float = 0.3
@export var ai_strafe_chance: float = 0.4
@export var ai_flank_chance: float = 0.3
@export var ai_jump_when_player_above: bool = true
@export var ai_jump_height_threshold: float = 50.0
@export var ai_jump_height_max: float = 360.0
@export var ai_wall_climb_when_needed: bool = true
@export var ai_stuck_detection_distance: float = 5.0
@export var ai_stuck_detection_time: float = 1.0
@export var ai_dash_distance_threshold: float = 300.0
@export var ai_dash_cooldown: float = 2.0

@export_subgroup("AI Decision")
@export var ai_think_time: float = 0.2
@export var ai_reconsider_time: float = 0.5
@export var ai_patience_time: float = 3.0
@export var ai_strafe_min_time: float = 0.5
@export var ai_strafe_max_time: float = 1.5
@export var ai_retreat_time: float = 2.0
@export var ai_flank_time: float = 1.5

@export_subgroup("AI Patrol")
@export var ai_patrol_idle_chance: float = 0.3
@export var ai_patrol_state_min_time: float = 1.0
@export var ai_patrol_state_max_time: float = 4.0
@export var ai_patrol_distance: float = 200.0
@export var ai_patrol_auto_generate: bool = true

@export_subgroup("AI Group")
@export var ai_soft_collision_strength: float = 100.0
@export var ai_soft_collision_max_force: float = 50.0
@export var ai_maintain_distance_from_allies: float = 100.0

@export_subgroup("AI Cooldowns")
@export var ai_jump_cooldown: float = 1.5
@export var ai_attack_cooldown_override: float = 0.0

@export_group("Body Options")
@export_subgroup("Body Sprites")
@export var body: Texture2D
@export var sword: Texture2D
@export var leg: Texture2D
@export var feet: Texture2D
@export var arm: Texture2D
@export var hand: Texture2D
@export var head: Texture2D
@export var eye_b: Texture2D
@export var eye_f: Texture2D
@export var feller_1: Texture2D
@export var feller_2: Texture2D
@export var mandible_f: Texture2D
@export var mandible_b: Texture2D

@export_subgroup("Body Colors")
@export var body_color: Color = Color.WHITE
@export var head_color: Color = Color.WHITE
@export var mandibles_color: Color = Color.WHITE
@export var weapon_color: Color = Color.WHITE
