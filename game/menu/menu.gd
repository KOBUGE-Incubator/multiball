extends Control

enum Type {TYPE_CLIENT, TYPE_SERVER, TYPE_BOTH}
class Level: 
	var path = ""
	var name = ""
	func _init(_path = "", _name = "Unnamed level"): path = _path; name = _name

export(NodePath) var grid_ = @"panel/parts/grid"

onready var grid = get_node(grid_)
onready var type_select = grid.get_node(@"type")
onready var host_field = grid.get_node(@"host")
onready var host_label = grid.get_node(@"host_label")
onready var max_players_field = grid.get_node(@"max_players")
onready var max_players_label = grid.get_node(@"max_players_label")
onready var port_field = grid.get_node(@"port")
onready var level_select = grid.get_node(@"level")
onready var level_label = grid.get_node(@"level_label")

var levels = []

func _ready():
	var dir = Directory.new()
	var level_dirs_left = ["res://levels", "user://levels"]
	while level_dirs_left.size() > 0:
		var open_result = dir.open(level_dirs_left[-1])
		level_dirs_left.pop_back()
		if open_result == OK:
			dir.list_dir_begin()
			while true:
				var file_name = dir.get_next()
				if file_name == "":
					break
				var file_path = dir.get_current_dir().plus_file(file_name)
				if dir.current_is_dir() and file_name != "." and file_name != "..":
					level_dirs_left.push_back(file_path)
				if file_name.match("level-*.?scn") or file_name.match("level-*.scn"):
					levels.push_back(Level.new(file_path, file_name.replace("level-","").basename()))
			dir.list_dir_end()
		
	for i in range(levels.size()):
		level_select.add_item(levels[i].name, i)
	
	for arg in OS.get_cmdline_args():
		if arg == "-c":
			type_select.select(0)
			start()
		elif arg == "-s":
			OS.set_window_minimized(true)
			type_select.select(1)
			start()
		elif arg == "-sc":
			type_select.select(2)
			start()
	
	type_select.select(2)
	type_changed(type_select.get_selected_ID())
	type_select.connect("item_selected", self, "type_changed")

func start():
	var type = type_select.get_selected_ID()
	var host = host_field.get_text()
	var port = int(port_field.get_text())
	var max_players = int(max_players_field.get_text())
	var level = levels[level_select.get_selected_ID()]
	_setup_tree(type, host, port, max_players, level.path)

func start_and_duplicate():
	start()
	OS.execute(OS.get_executable_path(), OS.get_cmdline_args(), false)

func _setup_tree(type, host, port, max_players, level_path, tree = get_tree()):
	var multiplayer = NetworkedMultiplayerENet.new()
	var error = OK
	if type == TYPE_SERVER:
		tree.get_root().set_network_mode(NETWORK_MODE_MASTER)
		error = multiplayer.create_server(port, max_players)
	else:
		tree.get_root().set_network_mode(NETWORK_MODE_SLAVE)
		error = multiplayer.create_client(host, port)
		if type == TYPE_BOTH:
			var scenetree_holder = preload("scenetree_holder.gd").new()
			scenetree_holder.set_name("server_tree_holder")
			get_tree().get_root().add_child(scenetree_holder)
			_setup_tree(TYPE_SERVER, host, port, max_players, level_path, scenetree_holder.scene_tree)
	
	if error:
		print("Couldn't create server/client! Error: ", error)
	else:
		tree.set_network_peer(multiplayer)
		tree.set_meta("network_peer", multiplayer)
	
	var game_node = preload("res://main/main.tscn").instance()
	tree.get_root().add_child(game_node)
	if tree.get_current_scene():
		tree.get_current_scene().queue_free()
	tree.set_current_scene(game_node)
	if type == TYPE_SERVER:
		game_node.load_level(level_path)

func type_changed(type):
	host_field.set_hidden(type == TYPE_SERVER)
	host_label.set_hidden(type == TYPE_SERVER)
	max_players_field.set_hidden(type == TYPE_CLIENT)
	max_players_label.set_hidden(type == TYPE_CLIENT)
	level_select.set_hidden(type == TYPE_CLIENT)
	level_label.set_hidden(type == TYPE_CLIENT)
