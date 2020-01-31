extends Signal

"""
A Source Signal providing player directional input
"""

func _ready():
	set_physics_process(true)
	_state = Vector2(0, 0)

func _physics_process(delta):
	var dir: = Vector2(0, 0)
	var move: = false
	if Input.is_action_pressed("player_left"):
		move = true
		dir += Vector2(-1, 0)
	if Input.is_action_pressed("player_right"):
		move = true
		dir += Vector2(1, 0)
	if Input.is_action_pressed("player_up"):
		move = true
		dir += Vector2(0, -1)
	if Input.is_action_pressed("player_down"):
		move = true
		dir += Vector2(0, 1)
	if move:
		dir = dir.normalized()
	sink_state(dir)
