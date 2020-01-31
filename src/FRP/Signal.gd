extends Node

class_name Signal

"""
Basic component for FRP components.

data Signal = Signal s a
	where:
		s is _state, a continuous state value emitting "updated" signal
		a is type of discrete event emitting "fired" signal

_xform is internal input transformer of type (t -> s) used during on_update

_map is a transformer of type (b -> a) used during on_fired
_snap is a transformer of type (s -> b -> a) used for snapshotting
_update is a transformer of type (s -> b -> s) used for updating state

_pred is a predicate of type (a -> Bool) for filtering

_map takes precedence over _snap
"""

signal updated(state)
signal fired(event)

# TODO Ugly class hack
var Self = load("res://src/FRP/Signal.gd")

var _is_ready = false
var _state = null setget _set_state, _get_state
# States for lifting
var _stateA
var _stateB

var _xform: FuncRef = null
var _lift: FuncRef = null
var _map: FuncRef = null
var _snap: FuncRef = null
var _update: FuncRef = null
var _pred: FuncRef = null

func _ready():
	_is_ready = true

########## Getters/Setters ##########

func _get_state():
	return _state


func _set_state(new_state):
	_state = new_state
	if _is_ready:
		emit_signal("updated", new_state)


########## FRP <> Pure interface ##########

func sample():
	assert(_is_ready)
	return _state

func sink_state(value):
	_set_state(value)

func sink_event(value):
	if _is_ready:
		emit_signal("fired", value)


########## FRP Primitives ##########

func mapstate(f: FuncRef) -> Signal:
	"""
	Bifunctor map first/Signal map state:
		Signal s a -> (s -> t) -> Signal t a
	
	Initialize new Signal with transformed current state
	
	Behavior:
		When current cell value is updated, new cell value is updated with transformation 
	"""
	var sig: Signal = Self.new()
	if _state != null && is_instance_valid(f):
		sig._state = f.call_func(_state)
	sig._xform = f
	connect("updated", sig, "_on_source_updated")
	return sig

func fmap(f: FuncRef) -> Signal:
	"""
	Functor map/Signal map event:
		Signal s a -> (a -> b) -> Signal t b
	
	Behavior:
		Event is passed through with transformation
	"""
	var sig: Signal = Self.new()
	sig._map = f
	connect("fired", sig, "_on_source_fired")
	return sig


func snapshot(s: Signal, f: FuncRef) -> Signal:
	"""
	Signal snapshot event:
		Signal _ a -> Signal s _ -> (s -> a -> b) -> Signal s b
	
	Behavior:
		If taken fired event, apply (f :: s -> a -> b) and fire resulting b
	"""
	var sig: Signal = Self.new()
	sig._snap = f
	sig._state = s._state
	s.connect("updated", sig, "_on_source_updated")
	connect("fired", sig, "_on_source_fired")
	return sig


func hold(state) -> Signal:
	"""
	Signal hold event:
		Signal t a -> a -> Signal a b
	"""
	var sig: Signal = Self.new()
	# Set initial state
	sig._state = state
	sig._update = funcref(self, "_update_hold")
	connect("fired", sig, "_on_source_fired")
	return sig


func accum(snap: FuncRef, update: FuncRef, state) -> Signal:
	"""
	Signal accumulate:
		Signal s a -> (s -> a -> b) -> (s -> a -> s) -> s -> Signal s b
	"""
	var sig: Signal = Self.new()
	sig._snap = snap
	sig._update = update
	sig._state = state
	connect("fired", sig, "_on_source_fired")
	return sig


func filter(pred: FuncRef) -> Signal:
	"""
	Signal filter:
		Signal s a -> (a -> Bool) -> Signal t a
	"""
	var sig: Signal = Self.new()
	sig._pred = pred
	connect("fired", sig, "_on_source_fired")
	return sig


func lift(b: Signal, f: FuncRef) -> Signal:
	"""
	Signal lifting:
		Signal s a -> Signal t b -> (s -> t -> u) -> Signal u c
	Behavior:
		New Signal's state is the combination of states of two lifted Signals
	"""
	var sig: Signal = Self.new()
	# Initial state
	sig._state = f.call_func(_state, b._state)
	sig._stateA = _state
	sig._stateB = b._state
	sig._lift = f
	connect("updated", sig, "_on_sourceA_updated")
	b.connect("updated", sig, "_on_sourceB_updated")
	return sig


func delay() -> Signal:
	"""
	Signal s a -> Signal s a
	Behavior:
		Identity, but defers signal propagation
	"""
	var sig: Signal = Self.new()
	connect("updated", sig, "_on_source_updated", [], CONNECT_DEFERRED)
	connect("fired", sig, "_on_source_fired", [], CONNECT_DEFERRED)
	return sig

func switch_state() -> Signal:
	"""
	Signal (Signal s a) b -> Signal s a
	Behavior:
		Switches active signal
	"""
	return mapstate(funcref(self, "_switch_xform"))

func switch_event() -> Signal:
	return null

########## Helpers constructed from primitives ##########

func snapshot_state(s: Signal) -> Signal:
	"""
	Snapshots the state only, discarding any input events
	"""
	return snapshot(s, funcref(self, "_snap_state"))

func accum_state(update: FuncRef, state) -> Signal:
	"""
	Signal t a -> (s -> a -> s) -> s -> Signal s b
	
	Accumulator updating state
	"""
	return accum(null, update, state)

########## Helpers ##########

func append(sig: Signal, name: String):
	sig.name = name
	add_child(sig)

########## Callbacks ##########

func _on_source_updated(st):
	var x = st
	if is_instance_valid(_xform):
		x = _xform.call_func(x)
	_set_state(x)


func _on_sourceA_updated(st):
	assert(is_instance_valid(_lift))
	assert(_stateB != null)
	_stateA = st
	_set_state(_lift.call_func(st, _stateB))


func _on_sourceB_updated(st):
	assert(is_instance_valid(_lift))
	assert(_stateA != null)
	_stateB = st
	_set_state(_lift.call_func(_stateA, st))


func _on_source_fired(event):
	var e = event
	
	# Event transformations
	if is_instance_valid(_map):
		# Functor mapping event
		e = _map.call_func(event)
	elif is_instance_valid(_snap):
		# Stateful mapping event
		e = _snap.call_func(_state, event)
	
	if is_instance_valid(_update):
		# State update from event
		_set_state(_update.call_func(_state, event))
	
	var propagate: bool = true
	if is_instance_valid(_pred):
		# Event filtering using predicate
		propagate = _pred.call_func(event)
	
	if _is_ready && propagate:
		emit_signal("fired", e)

########## Static ##########

func _snap_state(state, _event):
	"""
	Snapshotting the state
	"""
	return state

func _update_hold(_state, event):
	"""
	Holding event
	"""
	return event

func _switch_xform(_st):
	return _st.sample()
