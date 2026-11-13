extends CharacterBody3D
## Movement drives the selected model's in-place animations; the capsule owns collisions.

@export_range(0.1, 5.0, 0.1) var walk_speed: float = 1.6
@export_range(0.1, 30.0, 0.1) var acceleration: float = 8.0
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 10.0
@export var camera: Camera3D

# The library's root-motion equivalent covers 1.3 meters in 1.333 seconds.
const ANIMATION_WALK_SPEED: float = 0.975

@onready var model: Node3D = $Model
@onready var animations: AnimationPlayer = $Model/Library/AnimationPlayer

var horizontal_speed: float = 0.0
var animation_walk_speed: float = ANIMATION_WALK_SPEED
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _ready() -> void:
	var character := CharacterStore.selected_character()
	if not character.is_empty():
		var original := $Model/Library
		model.remove_child(original)
		original.queue_free()
		var visual := CharacterVisual.new()
		visual.name = "Library"
		visual.rotation.y = PI
		model.add_child(visual)
		visual.set_class(character.class_id)
		animations = visual.animations
		animation_walk_speed = 1.6
	# Both visual providers expose the same Idle / Walk animation names.
	animations.play("Idle")


func _physics_process(delta: float) -> void:
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(axes.x, 0.0, axes.y)
	if is_instance_valid(camera):
		var right := camera.global_basis.x
		var back := camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		direction = right.normalized() * axes.x + back.normalized() * axes.y
	# Keep diagonal movement at the same speed as a single axis.
	direction = direction.limit_length(1.0)
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	planar = planar.move_toward(direction * walk_speed, acceleration * delta)
	velocity.x = planar.x
	velocity.z = planar.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_speed = planar_velocity.length()
	if horizontal_speed > 0.05:
		var facing := atan2(-planar_velocity.x, -planar_velocity.z)
		model.rotation.y = lerp_angle(model.rotation.y, facing, 1.0 - exp(-turn_speed * delta))
	_animate_walk()
	# Recover safely if the character is moved beyond the study floor in the editor.
	if global_position.y < -10.0:
		global_position = Vector3.ZERO
		velocity = Vector3.ZERO


func _animate_walk() -> void:
	var walking := horizontal_speed > 0.08 and is_on_floor()
	var clip := "Walk" if walking else "Idle"
	if animations.current_animation != clip:
		animations.play(clip, 0.2)
	animations.speed_scale = maxf(horizontal_speed / animation_walk_speed, 0.15) if walking else 1.0
