
extends RigidBody

export var speed = 20.0 # The speed of the ball
export var camera_path = NodePath("../camera") # The path to the camera
var camera # The camera itself
var camera_offset = Vector3(0, 3, 6) # The offset from the camera

func _ready():
	# Get needed nodes
	camera = get_node(camera_path)
	
	set_fixed_process(true)
	set_process(true)

func _process(delta):
	# Transform the offset, so it is in "local" coords
	var rotation = get_rotation()
	var matrix = Matrix3(Vector3(0, 1, 0), rotation.y)
	var transformed_offset = matrix.xform(camera_offset)
	# Place the camera in the right place
	camera.set_translation(get_translation() + transformed_offset)

func _fixed_process(delta):
	var force = Vector3(0, 0, 0) # The force
	if(Input.is_action_pressed("forward")):
		force += Vector3(0, 0, -speed) # Move forward
	if(Input.is_action_pressed("back")):
		force += Vector3(0, 0, speed) # Move backward
	# Transform the force, so it is in "local" coords
	var rotation = get_rotation()
	var matrix = Matrix3(Vector3(0, 1, 0), rotation.y)
	force = matrix.xform(force)
	# Apply the force
	set_linear_velocity(get_linear_velocity() + force)

