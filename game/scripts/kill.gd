
extends Area

# member variables here, example:
# var a=2
# var b="textvar"
var ball_class = preload("res://scripts/ball.gd")

func _ready():
	connect("body_enter",self,"_body_enter")

func _body_enter(body):
	if(body extends ball_class):
		body.respawn()

