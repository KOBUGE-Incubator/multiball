extends Spatial

export(Color) var color = Color(0,0,0)
export(String) var name = "Red"

var checkpoints = {}

func _ready():
	set_transform(Transform())

func add_player(player):
	add_child(player)
	player.team = self

func get_player_count(): return get_child_count()
func get_players(): return get_children()

func add_checkpoint(checkpoint):
	checkpoints[checkpoint] = true
func remove_checkpoint(checkpoint):
	checkpoints.erase(checkpoint)
func get_checkpoints():
	return checkpoints.keys()
func get_checkpoint_count():
	return checkpoints.size()

func get_spawn_pos():
	var result = Vector3(0, 6, 0)
	var spawnpoints = get_node("../level").get_spawnpoints() # TODO, don't refer to level by exact path
	if checkpoints.size() > 0 or spawnpoints.size() > 0:
		var picked = randi() % (checkpoints.size() + spawnpoints.size())
		if picked < checkpoints.size():
			result = checkpoints.keys()[picked].get_translation() + Vector3(0,3,0)
		else:
			result = spawnpoints[picked - checkpoints.size()].get_translation()
	
	return result + Vector3(randf() * 2 - 1, 0, randf() * 2 - 1)