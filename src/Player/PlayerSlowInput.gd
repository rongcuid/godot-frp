extends Signal

"""
A Source Signal providing player slow input
"""

func _ready():
	set_physics_process(true)
	_state = false

func _physics_process(delta):
	if Input.is_action_pressed("player_slow") && not _state:
		sink_state(true)
	elif _state:
		sink_state(false)
