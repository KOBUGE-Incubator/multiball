extends Spatial

export var player_scene = preload("res://player/player.tscn")
export var local_player_scene = preload("res://player/player_local.tscn")

var peer_players = {}
var local_player = null
var teams = []

var level = null
var level_path = ""

func _ready():
	print("Initialized, mode: ", get_tree().get_root().get_network_mode())
	if is_network_master():
		get_tree().get_meta("network_peer").connect("peer_connected", self, "peer_connected")
		get_tree().get_meta("network_peer").connect("peer_disconnected", self, "peer_disconnected")

slave func load_level(path):
	level_path = path
	if is_network_master():
		rpc("load_level", path)
	
	if level:
		level.queue_free()
		remove_child(level)
	
	if path != "":
		level = load(path).instance()
		add_child(level)
	
	for team in get_children():
		if team extends preload("res://player/team.gd"):
			team.level = level
			teams.push_back(team)

func peer_connected(id):
	print(id, " connected!")
	
	for pp in peer_players:
		var team_name = peer_players[pp].get_parent().get_name()
		rpc_id(id, "make_player", team_name, pp)
	
	if level:
		rpc_id(id, "load_level", level_path)
		
		for checkpoint in level.get_checkpoints():
			checkpoint.update_status(true, id)
	
	var min_player_count = teams[0].get_player_count()
	var min_team = teams[0]
	for team in teams:
		if min_player_count > team.get_player_count():
			min_player_count = team.get_player_count()
			min_team = team
		
	rpc("make_player", min_team.get_name(), id)

func peer_disconnected(id):
	print(id, " disconnected!")
	rpc("unmake_player", id)

sync func make_player(team, id):
	team = get_node(team)
	var new_player = null
	if get_tree().get_meta("network_peer").get_unique_id() == id:
		new_player = local_player_scene.instance()
		local_player = new_player
	else:
		new_player = player_scene.instance()
	peer_players[id] = new_player
	new_player.set_name(str("player", id))
	new_player.set_meta("network_id", id)
	team.add_player(new_player)

sync func unmake_player(id):
	peer_players[id].queue_free()
	peer_players.erase(id)