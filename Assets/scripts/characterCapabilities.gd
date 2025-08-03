extends Resource
class_name CharacterCapabilities

@export_group("Basic Movement")
@export var can_walk: bool = true
@export var can_jump: bool = true

@export_group("Advanced Movement")
@export var can_double_jump: bool = false
@export var can_triple_jump: bool = false
@export var can_wall_jump: bool = false
@export var can_wall_slide: bool = false
@export var can_dash: bool = false

@export_group("Combat")
@export var can_attack: bool = true
@export var can_air_attack: bool = false
@export var can_combo_attack: bool = true
@export var max_combo_count: int = 3

@export_group("Special Abilities")
@export var can_big_jump: bool = false
@export var can_big_attack: bool = false
@export var can_dash_attack: bool = false

@export_group("AI Behavior")
@export var can_chase: bool = false
@export var can_patrol: bool = false
@export var patrol_chance_idle: float = 0.3
@export var initial_state_idle_chance: float = 0.5

@export_group("Detection")
@export var has_detection_area: bool = false
@export var detection_range: float = 600.0
@export var has_view_ray: bool = false
