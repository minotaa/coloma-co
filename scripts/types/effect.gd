class_name Effect
extends Object

var name: String
var duration: float
var color: Color
var potency: int = 0
var effect_time: float = 0.0 # Interval between triggers (0 = every tick)
var elapsed_time: float = 0.0
var effect_elapsed: float = 0.0

var on_apply: Callable = func (_target): pass
var on_effect: Callable = func (_target): pass
var on_end: Callable = func (_target): pass

func _init(_name: String, _color: Color, _duration: float, _potency: int = 0, _effect_time: float = 0.0):
	name = _name
	color = _color
	duration = _duration
	potency = _potency
	effect_time = _effect_time

func update(delta: float, target) -> bool:
	# Increase timers
	elapsed_time += delta
	effect_elapsed += delta

	# Trigger effect based on effect_time
	if effect_time == 0.0 or effect_elapsed >= effect_time:
		on_effect.call(target)
		effect_elapsed = 0.0

	# Check for expiration
	if elapsed_time >= duration:
		on_end.call(target)
		return true
	return false

func _to_string() -> String:
	return "StatusEffect(%s, duration=%.2f, effect_time=%.2f, elapsed=%.2f)" % [
		name, duration, effect_time, elapsed_time
	]