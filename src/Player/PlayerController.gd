extends Signal

"""
Top level player controller, taking ticks as input.

Additional inputs are used for controlling
"""

var scene_root: Node2D
onready var player_root: Node2D = get_node(player_node)

export(NodePath) var player_node: NodePath
export(float) var high_speed: = 600.0
export(float) var low_speed: = 300.0

var velocity_signal: Signal

func _ready():
	# Connect fire input
	var fire: = snapshot_state($FireInput)
	add_child(fire, true)
	var fire_event: = fire.filter(funcref(get_script(), "_firing"))
	add_child(fire_event, true)
	fire_event.connect("fired", self, "_on_fire_fired")
	# Calculate speed
	var velocity: Signal = $MovementInput.lift(
		$SlowInput, funcref(self, "_speed"))
	velocity_signal = velocity
	append(velocity, "Velocity")

func _speed(direction: Vector2, slow: bool) -> Vector2:
	var velocity: = direction * (low_speed if slow else high_speed)
	return velocity

func _on_fire_fired(_x):
	var Bullet = load("res://src/Bullet/Bullet.tscn")
	var b: Node2D = Bullet.instance()
	b.position = player_root.position
	scene_root.add_child(b)

static func _firing(fire: bool) -> bool:
	return fire
