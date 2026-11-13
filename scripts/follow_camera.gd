extends Camera3D
## A fixed view keeps WASD directions predictable while following the subject.

@export var target: Node3D
@export var follow_speed: float = 7.0
@export var offset := Vector3(4.2, 3.1, 6.0)
@export var focus_height: float = 1.0

var focus := Vector3.ZERO


func _ready() -> void:
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
