tool
extends RigidBody

## Constants ##


const possible_camera_offsets = [
	Vector3(0, 3, 0),
	Vector3(0, -3, 0),
	Vector3(0, 0, 1),
	Vector3(0, 0, -1)
]

## Exported Variables ##

export(int) var ping_sample_count = 10
export(float) var speed = 25.0 # The speed of the ball
export(float) var network_interpolation_smoothing = 3 # How much would we interpolate in a second
export(float) var network_interpolation_stop = 10 # How many units to stop interpolating after
export(ShaderMaterial) var material

## Variables ##

var team # The team of the player

var should_respawn = false # Should we respawn?

var last_force = Vector3()

var last_position_received = Vector3()
var last_rotation_received = Quat()
var last_velocity_received = Vector3()
var last_ping = 0
var average_ping = 0
var last_pings = []
var last_ping_n = 0
var is_local = false

func _ready():
	material = material.duplicate(true) # Ensure we are the only users of the material
	
	var to_set_material = [get_node(@"mesh")]
	while to_set_material.size():
		var node = to_set_material.pop_back()
		if node extends MeshInstance:
			node.set_material_override(material)
		to_set_material += node.get_children()
	
	team = get_node("../../")
	if !team extends preload("team.gd"):
		team = null
	else:
		material.set_shader_param("player_color", team.color)
	
	last_pings.resize(ping_sample_count)
	for i in range(ping_sample_count):
		last_pings[i] = 0
	
	if !get_tree().is_editor_hint():
		if is_network_master():
			respawn()

func _integrate_forces(state):
	var delta = state.get_step()
	
	state.set_linear_velocity(state.get_linear_velocity() + last_force*speed*delta)
	
	if is_network_master():
		if should_respawn:
			should_respawn = false
			call_deferred("respawn")
		rpc_unreliable("set_movement_params", get_transform(), state.get_linear_velocity(), state.get_angular_velocity(), last_force)
	else:
		# Interpolate frame
		
#		smoothing = smoothing * (smoothing + 1)
		if last_ping < average_ping or true:
			var smoothing = make_smoothing(delta, network_interpolation_smoothing) 
			var transform = state.get_transform()
			var interp_pos = last_position_received + last_velocity_received * last_ping
			transform.origin = transform.origin.linear_interpolate(interp_pos, smoothing)
			var quat = Quat(transform.basis).slerp(last_rotation_received, smoothing)
			transform.basis = Matrix3(quat)
			
			var velocity = state.get_linear_velocity()
			var angular_velocity = state.get_angular_velocity()
			state.set_transform(transform)
			state.set_linear_velocity(velocity)
			state.set_angular_velocity(angular_velocity)
			
			#past_position_received += velocity * delta
		else:
			pass

master func respawn():
	set_linear_velocity(Vector3(0,0,0))
	set_angular_velocity(Vector3(0,0,0))
	set_rotation(Vector3(0,0,0))
	if team:
		set_translation(team.get_spawn_pos())
	else:
		set_translation(Vector3()) # Sane default

master func set_force(force):
	last_ping = 0
	last_force = force

slave func set_movement_params(transform, velocity, angular_velocity, force):
	# Ring buffer update
	average_ping += (last_ping - last_pings[last_ping_n]) / ping_sample_count
	last_pings[last_ping_n] = last_ping
	last_ping_n = (last_ping_n + 1) % ping_sample_count
	# Prepare for interpolation
	if !is_local:
		last_force = force
	else:
		velocity += (force - last_force) * average_ping / 2
	
	if get_translation().distance_squared_to(transform.origin) > network_interpolation_stop * network_interpolation_stop:
		set_transform(transform)
	transform.origin += velocity * average_ping / 2
	last_position_received = transform.origin
	last_rotation_received = Quat(transform.basis)
	last_velocity_received = velocity
	set_linear_velocity(velocity)
	set_angular_velocity(angular_velocity)
	last_ping = 0

func make_smoothing(delta, smoothing):
	return clamp(smoothing * delta * (1 + delta), 0, 1)
