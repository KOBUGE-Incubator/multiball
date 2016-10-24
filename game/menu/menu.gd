extends Control

enum Type {TYPE_SERVER, TYPE_CLIENT, TYPE_BOTH}

export(NodePath) var type_select_
export(NodePath) var host_field_
export(NodePath) var host_label_
export(NodePath) var max_players_field_
export(NodePath) var max_players_label_
export(NodePath) var port_field_

onready var type_select = get_node(type_select_)
onready var host_field = get_node(host_field_)
onready var host_label = get_node(host_label_)
onready var max_players_field = get_node(max_players_field_)
onready var max_players_label = get_node(max_players_label_)
onready var port_field = get_node(port_field_)

func _ready():
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
	_setup_tree(type, host, port, max_players)

func start_and_duplicate():
	start()
	OS.execute(OS.get_executable_path(), OS.get_cmdline_args(), false)

func _setup_tree(type, host, port, max_players, tree = get_tree()):
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
			_setup_tree(TYPE_SERVER, host, port, max_players, scenetree_holder.scene_tree)
	
	if error:
		print("Couldn't create server/client! Error: ", error)
	else:
		tree.set_network_peer(multiplayer)
		tree.set_meta("network_peer", multiplayer)
	tree.change_scene_to(preload("res://main/main.tscn"))

func type_changed(type):
	host_field.set_hidden(type == TYPE_SERVER)
	host_label.set_hidden(type == TYPE_SERVER)
	max_players_field.set_hidden(type == TYPE_CLIENT)
	max_players_label.set_hidden(type == TYPE_CLIENT)
