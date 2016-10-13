extends Spatial

var spawnpoints = []
var checkpoints = []

func _ready():
	var to_check = [self]
	while to_check.size():
		var node = to_check.pop_back()
		if node extends Position3D:
			spawnpoints.push_back(node)
		if node extends preload("res://objects/checkpoints/checkpoint.gd"):
			node.level = self
			checkpoints.push_back(node)
		to_check += node.get_children()

func get_spawnpoints(): return spawnpoints
func get_checkpoints(): return checkpoints
