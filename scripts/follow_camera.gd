extends Camera3D
## Follow the subject, orbit with a middle-button drag, and zoom with the wheel.

const MIN_PITCH: float = PI / 18.0
const MAX_PITCH: float = PI * 4.0 / 9.0

@export var target: Node3D
@export var follow_speed: float = 7.0
@export var offset := Vector3(12.6, 9.3, 18.0)
@export var focus_height: float = 1.0
@export var min_distance: float = 3.0
@export var max_distance: float = 48.0
@export var orbit_sensitivity: float = 0.005
@export var zoom_step: float = 1.15

var focus := Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _distance: float = 0.0
var _orbiting: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_distance = clampf(offset.length(), min_distance, max_distance)
	_yaw = atan2(offset.x, offset.z)
	_pitch = clampf(atan2(offset.y, Vector2(offset.x, offset.z).length()), MIN_PITCH, MAX_PITCH)
	_update_offset()
	if is_instance_valid(target):
		focus = target.global_position + Vector3.UP * focus_height
		global_position = focus + offset
		look_at(focus)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired := target.global_position + Vector3.UP * focus_height
	focus = focus.lerp(desired, 1.0 - exp(-follow_speed * delta))
	global_position = focus + offset
	look_at(focus)


func _input(event: InputEvent) -> void:
	if not _orbiting:
		return
	# Finish a drag even if its release occurs over a UI control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_stop_orbit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_yaw = wrapf(_yaw - event.screen_relative.x * orbit_sensitivity, -PI, PI)
		_pitch = clampf(_pitch + event.screen_relative.y * orbit_sensitivity, MIN_PITCH, MAX_PITCH)
		_update_offset()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			if _orbiting:
				return
			_previous_mouse_mode = Input.mouse_mode
			_orbiting = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			var steps: float = event.factor if event.factor > 0.0 else 1.0
			_distance = clampf(_distance * pow(zoom_step, direction * steps), min_distance, max_distance)
			_update_offset()
		_:
			return
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_stop_orbit()


func _exit_tree() -> void:
	_stop_orbit()


func _stop_orbit() -> void:
	if _orbiting:
		_orbiting = false
		Input.mouse_mode = _previous_mouse_mode


func _update_offset() -> void:
	var horizontal := cos(_pitch) * _distance
	offset = Vector3(sin(_yaw) * horizontal, sin(_pitch) * _distance, cos(_yaw) * horizontal)
