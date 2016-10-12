extends Area

const Player = preload("res://player/player.gd")

func _ready():
	connect("body_enter",self,"_body_enter")

func _body_enter(body):
	if body extends Player:
		body.respawn()

