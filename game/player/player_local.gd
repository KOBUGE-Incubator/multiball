extends "player.gd"

## Constants ##


const possible_camera_offsets = [
	Vector3(0, 3, 0),
	Vector3(0, -3, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1)
]

## Exported Variables ##

export(float) var rotation_speed = 20.0 # The speed of rotaion of the ball
export(float) var rotation_carry = 1.0 # How much of the rotation speed is carried over
export(float) var rotation_damp = 0.3 # How much of the rotation speed is retained for the next second
export(float) var camera_smoothing = 2 # How much of the total distance would the camera move in a second
export(float) var rotational_camera_smoothing = 2 # How much of the total rotation would the camera move in a second
export(float) var force_to_camera = -0.1 # How much of the force goes into the camera
export(Vector3) var mouse_scale = Vector3(2,3,0) # The scale of the mouse's interaction to the camera
export(Vector3) var mouse_motion_scale = Vector3(0,0,0) # The scale of the mouse movement behavior
export(Vector3) var default_camera_offset = Vector3(0, 3, 5) # The default offset from the camera

## Nodes ##

onready var camera = get_node(@"../camera") # The camera itself

## Variables ##

onready var default_camera_offset_length = default_camera_offset.length()

var camera_offset = default_camera_offset # The offset from the camera
var target_camera_offset = camera_offset # An offset towards which we will move the camera
var has_not_seen_ball_from = 0.0 # How much time passed from the last time we saw that ball

var rotation_y = 0 # the rotation of the camera and movement on y
var rotation_y_velocity = 0 # The speed of rotation on Y

var mouse_pos = Vector2(0,0) # The position of the mouse

func _ready():
	is_local = true
	camera.set_translation(get_translation() + camera_offset)
	
	if !get_tree().is_editor_hint():
		set_fixed_process(true)
		set_process(true)
		set_process_input(true)

func respawn():
	set_linear_velocity(Vector3(0,0,0))
	set_angular_velocity(Vector3(0,0,0))
	set_rotation(Vector3(0,0,0))
	rotation_y = round(rand_range(0, 8))*PI/4
	rotation_y_velocity = 0
	if team:
		set_translation(team.get_spawn_pos())
		material.set_shader_param("player_color", team.color)
	else:
		set_translation(Vector3()) # Sane default

func _input(event):
	if(event.is_action("respawn") && event.is_pressed() && !event.is_echo()):
		rpc("respawn")
	if(event.type == InputEvent.MOUSE_MOTION):
		mouse_pos = (event.pos / OS.get_window_size() - Vector2(0.5,0.5))

func _process(delta):
	var rotation_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	var transformed_offset = rotation_matrix.xform(target_camera_offset)
	var transformed_mouse = rotation_matrix.xform(Vector3(mouse_pos.x, mouse_pos.y, 0) * mouse_scale)
	var target_camera_pos = get_translation() + transformed_offset + transformed_mouse
	# Place the camera in the right place, and interpolate
	camera.set_translation(camera.get_translation().linear_interpolate(target_camera_pos, make_smoothing(delta, camera_smoothing)))
	# Rotate the camera, so that it looks at the ball
	var current_transform = camera.get_transform()
	var new_transform = current_transform.looking_at(get_translation(), Vector3(0, 1, 0))
	var current_quat = Quat(current_transform.basis)
	var new_quat = Quat(new_transform.basis)
	new_transform.basis = Matrix3(current_quat.slerp(new_quat, make_smoothing(delta, rotational_camera_smoothing)))
	camera.set_transform(new_transform)

func _fixed_process(delta):
	last_ping += delta
	# Interpolate stuffs
	rotation_y += rotation_y_velocity * delta
	rotation_y_velocity *= 1 - rotation_damp * delta
	
	var rotation_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	
	var force = Vector3(mouse_pos.x, 0, mouse_pos.y)*mouse_motion_scale # The force 
	if Input.is_action_pressed("forward"):
		force += Vector3(0, 0, -1) # Move forward
	if Input.is_action_pressed("back"):
		force += Vector3(0, 0, 1) # Move backward
	if Input.is_action_pressed("rotate_right"):
		force += Vector3(0.5, 0, 0) # Move right
	if Input.is_action_pressed("rotate_left"):
		force += Vector3(-0.5, 0, 0) # Move right
	
	if force.length_squared() > 1:
		force = force.normalized()  # Ensure that the force isn't too much
	
	# Add some rotation
	rotation_y_velocity += (rotation_speed*delta + sqrt(abs(rotation_y_velocity))*rotation_carry)*force.x
	
	target_camera_offset = target_camera_offset + force*force_to_camera
	# Transform the force, so it is in rotated coords
	force = rotation_matrix.xform(force)
	# Apply the forces
	last_force = force
	rpc("set_force", force)
	
	fix_camera(delta)


func fix_camera(delta):
	# Check if we can see the ball, and if not, move the camera
	var rotation_matrix = Matrix3(Vector3(0, 1, 0), rotation_y)
	var camera_pos = get_translation() + rotation_matrix.xform(target_camera_offset)
	var space_state = get_world().get_direct_space_state()
	var intersection = space_state.intersect_ray(camera_pos, get_translation(), [self])
	if intersection.has("position"): # Noes, something is in the way!
		has_not_seen_ball_from += delta
		
		for new_camera_offset in possible_camera_offsets:
			new_camera_offset = (target_camera_offset + new_camera_offset).normalized() * default_camera_offset_length
			var new_camera_pos = get_translation() + rotation_matrix.xform(new_camera_offset)
			# Will we be able to see ball if we move the camera there?
			var new_intersection = space_state.intersect_ray(new_camera_pos, get_translation(), [self])
			if !new_intersection.has("position"): # We can move the camera
				target_camera_offset = new_camera_offset
				return
		if has_not_seen_ball_from > 0.5:
			# We won't see it from anywhere, thus our solution is to zoom in
			var direction = (camera_pos - get_translation()).normalized()
			var intersection_offset = intersection["position"] - camera_pos
			target_camera_offset = direction*(intersection_offset.dot(direction))
		# Better be safe than sorry.. if we change the x, we would lie the player about the ball's orientation
		target_camera_offset.x = 0
	else: # We see the ball but it would be nice to go back to the original position
		var default_camera_pos = get_translation() + rotation_matrix.xform(default_camera_offset)
		var default_intersection = space_state.intersect_ray(default_camera_pos, get_translation(), [self])
		if !default_intersection.has("position"):
			target_camera_offset = target_camera_offset.linear_interpolate(default_camera_offset, make_smoothing(delta, camera_smoothing))
		
		has_not_seen_ball_from = 0.0 # We just saw it
