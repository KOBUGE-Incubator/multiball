
extends RigidBody

export var speed = 20.0 # The speed of the ball
export var rotation_speed = 20.0 # The speed of rotaion of the ball
export var camera_path = NodePath("../camera") # The path to the camera
var camera # The camera itself
var camera_offset = Vector3(0, 3, 6) # The offset from the camera
var rotation_y = 0 # the rotation of the camera on y
var rotation_y_speed = 0 # The speed of rotation on Y

func _ready():
	# Get needed nodes
	camera = get_node(camera_path)
	
	set_fixed_process(true)
	set_process(true)

func set_color(color):
	get_node("mesh").get_material_override().set_shader_param("Color",color)

func _process(delta):
	# Transform the offset, so it is in "local" coords
	var matrix = get_transform().inverse().basis
	rotation_y_speed = lerp(rotation_y_speed,0,delta*2)
	rotation_y += rotation_y_speed*delta
	var transform_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	var transformed_offset = transform_matrix.xform(camera_offset)
	# Place the camera in the right place
	camera.set_translation(get_translation() + transformed_offset) # Todo, interpolate the camera...
	# Rotate the camera, so it looks at the ball
	var current_transform = camera.get_transform()
	current_transform = current_transform.looking_at(get_translation(), Vector3(0, 1, 0))
	camera.set_transform(current_transform) # Todo, interpolate the camera...

func _fixed_process(delta):
	var force = Vector3(0, 0, 0) # The force
	if(Input.is_action_pressed("forward")):
		force += Vector3(0, 0, -speed) # Move forward
	if(Input.is_action_pressed("back")):
		force += Vector3(0, 0, speed) # Move backward
	if(Input.is_action_pressed("rotate_right")):
		force += Vector3(speed/2, 0, 0) # Move right
		rotation_y_speed += rotation_speed*delta
	if(Input.is_action_pressed("rotate_left")):
		force += Vector3(-speed/2, 0, 0) # Move right
		rotation_y_speed -= rotation_speed*delta
	# Transform the force, so it is in "camera" coords
	var transform_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	force = transform_matrix.xform(force)
	# Apply the forces
	set_linear_velocity(get_linear_velocity() + force*delta)

