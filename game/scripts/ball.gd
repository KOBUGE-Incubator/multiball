
extends RigidBody

export var speed = 20.0 # The speed of the ball
export var rotation_speed = 20.0 # The speed of rotaion of the ball
export var rotation_carry = 1.0 # How much of the rotation speed is carried over?
export var camera_path = NodePath("../camera") # The path to the camera
export var mouse_scale = Vector3(2,3,0)
export var mouse_motion_scale = Vector3(0,0,0)
var camera # The camera itself
var default_camera_offset = Vector3(0, 3, 5) # The default offset from the camera
var camera_offset = default_camera_offset # The offset from the camera
var target_camera_offset = camera_offset # An offset towards which we will move the camera
var target_camera_pos = camera_offset #  A point towards which we will move the camera
var rotation_y = 0 # the rotation of the camera on y
var rotation_y_speed = 0 # The speed of rotation on Y
var start_pos = Vector3(-1.5,5,-1.5) # The starting position # TODO
var should_respawn = false # Should we respawn?
var phisics_space # the phisics space, used to perform raycasts
var have_not_seen_ball_from = 0.0 # How much time passed from the last time we saw that ball
var mouse_pos = Vector3(0,0,0) # The position of the mouse

func _ready():
	# Get needed nodes and stuff
	camera = get_node(camera_path)
	phisics_space = get_world().get_direct_space_state()
	# Start over
	respawn();
	set_fixed_process(true)
	set_process(true)
	set_process_input(true)

func set_color(color):
	get_node("mesh").get_material_override().set_shader_param("Color",color)

func respawn():
	set_translation(start_pos)
	set_linear_velocity(Vector3(0,0,0))
	set_angular_velocity(Vector3(0,0,0))
	set_rotation(Vector3(0,0,0))
	rotation_y = round(rand_range(0, 4))*PI/2
	rotation_y_speed = 0
	for i in range(10):
		if(OS.get_unix_time() % 10 < 5):
			var tmp = rand_range(0,1)
	set_color(Color(rand_range(0,1),rand_range(0,1),rand_range(0,1)))

func _input(event):
	if(event.is_action("respawn") && event.is_pressed() && !event.is_echo()):
		should_respawn = true
	if(event.type == InputEvent.MOUSE_MOTION):
		mouse_pos = (event.pos / OS.get_window_size() - Vector2(0.5,0.5))

func _process(delta):
	# Transform the offset, so it is in "local" coords
	# Place the camera in the right place
	var transform_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	camera.set_translation(target_camera_pos)
	# Rotate the camera, so it looks at the ball
	var current_transform = camera.get_transform()
	current_transform = current_transform.looking_at(get_translation(), Vector3(0, 1, 0))
	camera.set_transform(current_transform) # Todo, interpolate the camera...
	camera.get_node("../../GUI/FPS").set_text(str(OS.get_frames_per_second(), " FPS/",delta, " ms"))

func _fixed_process(delta):
	# Interpolate
	rotation_y += rotation_y_speed*delta
	var transform_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	var transformed_offset = transform_matrix.xform(camera_offset)
	camera_offset = camera_offset.linear_interpolate(target_camera_offset, delta*3)
	rotation_y_speed = lerp(rotation_y_speed,0,delta*2)
	var new_target_camera_pos = get_translation() + transformed_offset + transform_matrix.xform(Vector3(mouse_pos.x, mouse_pos.y, 0) * mouse_scale)
	target_camera_pos = target_camera_pos.linear_interpolate(new_target_camera_pos, delta*6)
	if(should_respawn): # Must we respawn
		should_respawn = false
		respawn()
		return # Don't calculate movement
	var force = Vector3(mouse_pos.x, 0, mouse_pos.y)*mouse_motion_scale # The force 
	if(Input.is_action_pressed("forward")):
		force += Vector3(0, 0, -1) # Move forward
	if(Input.is_action_pressed("back")):
		force += Vector3(0, 0, 1) # Move backward
	if(Input.is_action_pressed("rotate_right")):
		force += Vector3(0.5, 0, 0) # Move right
	if(Input.is_action_pressed("rotate_left")):
		force += Vector3(-0.5, 0, 0) # Move right
	
	rotation_y_speed += (rotation_speed*delta + sqrt(abs(rotation_y_speed))/rotation_carry)*force.x # Rotate the camera
	# Transform the force, so it is in "camera" coords
	force = transform_matrix.xform(force)
	if(force.length_squared() > 1):
		force = force.normalized()
	# Apply the forces
	set_linear_velocity(get_linear_velocity() + force*speed*delta)
	target_camera_offset += force/2
	target_camera_offset = target_camera_offset.linear_interpolate(default_camera_offset, delta*10)
	# Check if we can see the ball, and if not, move the camera
	var camera_pos = get_translation() + transform_matrix.xform(target_camera_offset)
	var intersection = phisics_space.intersect_ray(camera_pos, get_translation(), [self])
	if(intersection.has("position")): # We don't see the ball now
		have_not_seen_ball_from += delta
		# Will we be able to see ball if we move the camera up?
		var top_intersection = phisics_space.intersect_ray(camera_pos + Vector3(0, 3, 0), get_translation(), [self])
		# Will we be able to see ball if we move the camera down?
		var bottom_intersection = phisics_space.intersect_ray(camera_pos + Vector3(0, -3, 0), get_translation(), [self])
		if(top_intersection.has("position") && bottom_intersection.has("position") && have_not_seen_ball_from > 0.5): # We won't see it from above or below, and our only solution is to zoom in
			var direction = (camera_pos - get_translation()).normalized()
			target_camera_offset = direction*((intersection["position"] - camera_pos).dot(direction))
		elif(bottom_intersection.has("position")):
			target_camera_offset = target_camera_offset + Vector3(0, 3, 0) # Otherwise we will just move the camera up
		else:
			target_camera_offset = target_camera_offset + Vector3(0, -3, 0) # Otherwise we will just move the camera down
		target_camera_offset.x = 0
	else:
		if(target_camera_offset.distance_to(default_camera_offset) > 0.2): # We see the ball but it would be nice to go back to the original position
			# Will we be able to see ball if we move the camera to the default position?
			var default_intersection = phisics_space.intersect_ray(get_translation() + transform_matrix.xform(default_camera_offset), get_translation(), [self])
			if(! default_intersection.has("position")): # We will see it if we go back to defaults
				target_camera_offset = default_camera_offset
			elif(target_camera_offset.distance_to(default_camera_offset) > 10):# Don't get too far
				target_camera_offset = default_camera_offset
		else:
			have_not_seen_ball_from = 0.0 # We saw it
			
			

