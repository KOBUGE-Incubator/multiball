extends Area

const Player = preload("res://player/player.gd")

export(Color) var default_color = Color(0,0,0)
export(float) var min_alpha = 0.0
export(float) var max_alpha = 1.0
export(float, EASE) var color_transition = 1
export(float, EASE) var alpha_transition = 1
export(float) var max_team_weight = 10
export(float) var team_weight = 0

var material
var last_updated_weight = 0
var level = null

var team = null

func _ready():
	# Ensure checkpoints' colors are seperate
	material = get_node("mesh/Cylinder").get_material_override()
	material = material.duplicate(true)
	get_node("mesh/Cylinder").set_material_override(material)
	update_status()
	set_fixed_process(is_network_master())

func update_status(team_changed=false, for_id=0):
	last_updated_weight = team_weight
	var new_color = default_color
	if team:
		new_color = team.color
	new_color.a = max_alpha
	var interpolated = default_color.linear_interpolate(new_color, ease(team_weight / max_team_weight, color_transition))
	interpolated.a = lerp(min_alpha, max_alpha, ease(team_weight / max_team_weight, alpha_transition))
	material.set_shader_param("texture_color", interpolated)
	# TODO: Simplyfy following lines.. somehow
	if is_network_master():
		if for_id != 0:
			rpc_id(for_id, "update_weight", team_weight)
			if team:
				rpc_id(for_id, "update_team", team.get_name())
			else:
				rpc_id(for_id, "update_team", "")
		else:
			rpc_unreliable("update_weight", team_weight)
			if team_changed:
				if team:
					rpc("update_team", team.get_name())
				else:
					rpc("update_team", "")

slave func update_weight(new_weight):
	team_weight = new_weight
	update_status()

slave func update_team(team_name):
	if team_name != null and level != null:
		if team_name == "":
			team = null
		else:
			team = level.get_parent().get_node(team_name)
	update_status()

func _fixed_process(delta):
	if !is_network_master():
		return
	var weight_change = 0
	var other_team_counts = {}
	for body in get_overlapping_bodies():
		if body extends Player:
			if body.team == team:
				weight_change += 1
			else:
				if !other_team_counts.has(body.team):
					other_team_counts[body.team] = 0
				other_team_counts[body.team] += 1
				weight_change -= 1
	if weight_change != 0:
		var old_team = team
		team_weight += weight_change * delta
		if team_weight < 0:
			if team:
				team.remove_checkpoint(self)
			var max_team_count = 0
			for new_team in other_team_counts:
				if other_team_counts[new_team] > max_team_count:
					max_team_count = other_team_counts[new_team]
					team = new_team
				elif other_team_counts[new_team] == max_team_count:
					team = null
			if team:
				team.add_checkpoint(self)
		team_weight = clamp(team_weight, 0, max_team_weight)
		if old_team != team or abs(last_updated_weight - team_weight) < 0.1:
			update_status(old_team != team)
