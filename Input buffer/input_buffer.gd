extends Node
# Keeps track of recent inputs in order to make timing windows more flexible.
# Intended use: Add this file to your project as an Autoload script and have other objects call the class' methods.
# (more on AutoLoad: https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)

# How many milliseconds ahead of time the player can make an input and have it still be recognized.
# I chose the value 150 because it imitates the 9-frame buffer window in the Super Smash Bros. Ultimate game.
const BUFFER_WINDOW: int = 150
# The godot default deadzone is 0.2 so I chose to have it the same
const JOY_DEADZONE: float = 0.2

# Should be easy to add new supported events by adding them to this dictionary
var event_type_map: Dictionary = {
	"InputEventKey": {
		"timestamps": {},
		"get_key": func(event): return event.physical_keycode,
		"should_record_new_timestamp": func(event): return event.pressed && !event.is_echo()
	}, 
	"InputEventMouseButton": {
		"timestamps": {},
		"get_key": func(event): return event.button_index,
		"should_record_new_timestamp": func(event): return event.pressed && !event.is_echo()
	},  
	"InputEventJoypadButton": {
		"timestamps": {},
		"get_key": func(event): return event.button_index,
		"should_record_new_timestamp": func(event): return event.pressed && !event.is_echo()
	},  
	"InputEventJoypadMotion": {
		"timestamps": {},
		"get_key": func(event): return str(event.axis) + "_" + str(sign(event.axis_value)),
		"should_record_new_timestamp": func(event): return abs(event.axis_value) >= JOY_DEADZONE,
		"should_exit_is_action_press_buffered": func(event): return abs(event.axis_value) < JOY_DEADZONE
	},  
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

# Called whenever the player makes an input.
func _input(event: InputEvent) -> void:
	if !event_type_map.has(event.get_class()):
		return
	if !_should_record_new_timestamp(event):
		return
	_get_timestamps(event)[_get_timestamps_key(event)] = Time.get_ticks_msec()


# Returns whether any of the keyboard keys or joypad buttons in the given action were pressed within the buffer window.
func is_action_press_buffered(action: String, buffer_window: int = BUFFER_WINDOW) -> bool:
	# Get the inputs associated with the action. If any one of them was pressed in the last buffer_window milliseconds,
	# the action is buffered.
	for event in InputMap.action_get_events(action):
		if !event_type_map.has(event.get_class()):
			continue
		if _should_exit_is_action_press_buffered(event):
			return false
		if _get_timestamps(event).has(_get_timestamps_key(event)):
			var delta = Time.get_ticks_msec() - _get_timestamps(event)[_get_timestamps_key(event)]
			if delta <= buffer_window:
				# Prevent this method from returning true repeatedly and registering duplicate actions.
				_invalidate_action(action)
				return true
	return false


# Records unreasonable timestamps for all the inputs in an action. Called when IsActionPressBuffered returns true, as
# otherwise it would continue returning true every frame for the rest of the buffer window.
func _invalidate_action(action: String) -> void:
	for event in InputMap.action_get_events(action):
		var event_class = event.get_class()
		if !event_type_map.has(event_class):
			continue
		if _get_timestamps(event).has(_get_timestamps_key(event)):
			_get_timestamps(event)[_get_timestamps_key(event)] = 0

func _get_timestamps(event):
	return event_type_map[event.get_class()].timestamps

func _get_timestamps_key(event):
	return event_type_map[event.get_class()].get_key.call(event)

func _should_record_new_timestamp(event):
	return event_type_map[event.get_class()].should_record_new_timestamp.call(event)

func _should_exit_is_action_press_buffered(event):
	return event_type_map[event.get_class()].get(
		"should_exit_is_action_press_buffered", 
		func(_event): return false
	).call(event)
