extends Control

onready var fps = get_node("FPS")
onready var ping = get_node("ping")

func _ready():
	set_process(true)

func _process(delta):
	fps.set_text(str(OS.get_frames_per_second(), " FPS/", delta, " ms"))
	if get_parent().local_player:
		var average_ping = get_parent().local_player.get_node("rigidbody").average_ping
		ping.set_text(str(round(average_ping * 1000), " rtt"))
