extends Node

onready var scene_tree = SceneTree.new()

func _ready():
	scene_tree.init()
	scene_tree.get_root().set_as_render_target(true)
	scene_tree.get_root().set_rect(Rect2(0, 0, 0, 0))
	set_process(true)
	set_fixed_process(true)

func _process(delta):
	scene_tree.idle(delta)

func _fixed_process(delta):
	scene_tree.iteration(delta)

func _exit_tree():
	scene_tree.finish()
