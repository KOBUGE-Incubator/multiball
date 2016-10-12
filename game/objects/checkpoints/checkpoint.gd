extends Area

const Player = preload("res://player/player.gd")

export(Color) var default_color = Color(0,0,0)
export(float) var min_alpha = 0.0
export(float) var max_alpha = 1.0
export(float, EASE) var color_transition = 1
export(float, EASE) var alpha_transition = 1
export(float) var max_team_weight = 10

var material

var team = null
var team_weight = 0

func _ready():
	# Ensure checkpoints' colors are seperate
	material = get_node("mesh/Cylinder").get_material_override()
	material = material.duplicate(true)
	get_node("mesh/Cylinder").set_material_override(material)
	update_color()
	set_fixed_process(true)

func update_color():
	var new_color = Color()
	if team:
		new_color = team.color
	new_color.a = max_alpha
	var interpolated = default_color.linear_interpolate(new_color, ease(team_weight / max_team_weight, color_transition))
	interpolated.a = lerp(min_alpha, max_alpha, ease(team_weight / max_team_weight, alpha_transition))
	material.set_shader_param("texture_color", interpolated)

func _fixed_process(delta):
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
		update_color()
