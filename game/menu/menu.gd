extends Control

export(NodePath) var server_checkbox_
export(NodePath) var host_field_
export(NodePath) var host_label_
export(NodePath) var max_players_field_
export(NodePath) var max_players_label_
export(NodePath) var port_field_

onready var server_checkbox = get_node(server_checkbox_)
onready var host_field = get_node(host_field_)
onready var host_label = get_node(host_label_)
onready var max_players_field = get_node(max_players_field_)
onready var max_players_label = get_node(max_players_label_)
onready var port_field = get_node(port_field_)

func _ready():
	for arg in OS.get_cmdline_args():
		if arg == "-s":
			OS.set_window_minimized(true)
			server_checkbox.set_pressed(true)
			start()
		elif arg == "-c":
			server_checkbox.set_pressed(false)
			start()
	server_toggled(server_checkbox.is_pressed())
	server_checkbox.connect("toggled", self, "server_toggled")

func start():
	var host = host_field.get_text()
	var port = int(port_field.get_text())
	var max_players = int(max_players_field.get_text())
	var is_server = server_checkbox.is_pressed()
	var multiplayer = NetworkedMultiplayerENet.new()
	var error = OK
	if is_server:
		get_tree().get_root().set_network_mode(NETWORK_MODE_MASTER)
		error = multiplayer.create_server(port, max_players)
	else:
		get_tree().get_root().set_network_mode(NETWORK_MODE_SLAVE)
		error = multiplayer.create_client(host, port)
	
	if error:
		print("Couldn't create server/client! Error: ", error)
	else:
		get_tree().set_network_peer(multiplayer)
		get_tree().set_meta("network_peer", multiplayer)
	get_tree().change_scene_to(preload("res://main/main.tscn"))

func start_and_duplicate():
	start()
	OS.execute(OS.get_executable_path(), OS.get_cmdline_args(), false)

func server_toggled(state):
	host_field.set_hidden(state)
	host_label.set_hidden(state)
	max_players_field.set_hidden(!state)
	max_players_label.set_hidden(!state)