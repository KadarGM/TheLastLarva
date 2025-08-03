extends Node2D


func _ready() -> void:
	set_ordering()

func set_ordering() -> void:
	var childerns = get_tree().get_nodes_in_group("Enemy")
	for i in childerns.size():
		childerns[i].z_index = i * 100
