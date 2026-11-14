extends CharacterBody3D
## Movement drives the selected model's in-place animations; the capsule owns collisions.

@export_range(0.1, 5.0, 0.1) var walk_speed: float = 1.6
@export_range(0.1, 30.0, 0.1) var acceleration: float = 8.0
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 10.0
@export var camera: Camera3D

# The library's root-motion equivalent covers 1.3 meters in 1.333 seconds.
const ANIMATION_WALK_SPEED: float = 0.975
const MAX_HEALTH: int = 100

signal respawned

@onready var model: Node3D = $Model
var animations: AnimationPlayer

var horizontal_speed: float = 0.0
var animation_walk_speed: float = ANIMATION_WALK_SPEED
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var definition: CharacterClass
var health: int = MAX_HEALTH
var target: BasicSkeleton
var auto_attacking: bool = false
var attack_cooldown: float = 0.0
var attack_remaining: float = 0.0
var pending_target: BasicSkeleton
var spawn_position: Vector3


func _ready() -> void:
	spawn_position = global_position
	var character := CharacterStore.selected_character()
	var visual := CharacterVisual.new()
	visual.name = "Library"
	visual.rotation.y = PI
	model.add_child(visual)
	if not character.is_empty():
		visual.set_class(character.class_id)
		definition = CharacterClasses.find_class(character.class_id)
		add_to_group("player_characters")
		visual.equip_weapon(definition.basic_weapon)
		set_collision_mask_value(2, true)
		animation_walk_speed = 1.6
	else:
		visual.set_mannequin()
		if visual.using_fallback:
			animation_walk_speed = 1.6
	animations = visual.animations
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
	_update_combat(delta)
	if attack_remaining <= 0.0:
		_animate_walk()
	# Recover safely if the character is moved beyond the study floor in the editor.
	if global_position.y < -10.0:
		global_position = Vector3.ZERO
		velocity = Vector3.ZERO


func select_target(enemy: BasicSkeleton) -> void:
	if target != enemy:
		pending_target = null
	if is_instance_valid(target):
		target.set_selected(false)
	target = enemy
	if is_instance_valid(target):
		target.set_selected(true)
	auto_attacking = false


func stop_combat() -> void:
	select_target(null)
	pending_target = null
	attack_remaining = 0.0
	attack_cooldown = 0.0


func _update_combat(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_remaining > 0.0:
		attack_remaining = maxf(0.0, attack_remaining - delta)
		if pending_target != null and attack_remaining <= 0.28:
			var victim := pending_target
			pending_target = null
			# Resolve at impact, so moving away during the swing can avoid a hit.
			if is_instance_valid(victim) and not victim.dead and _in_attack_range(victim):
				victim.take_damage(definition.basic_damage, self, &"basic")
	if definition == null:
		return
	if not is_instance_valid(target) or target.dead:
		select_target(null)
	if target == null or not _in_attack_range(target):
		var nearby := _nearest_enemy_in_range()
		if nearby != null:
			select_target(nearby)
	auto_attacking = is_instance_valid(target) and _in_attack_range(target)
	if not auto_attacking:
		return
	var offset := target.global_position - global_position
	model.rotation.y = atan2(-offset.x, -offset.z)
	if attack_cooldown <= 0.0 and attack_remaining <= 0.0 and _in_attack_range(target):
		pending_target = target
		attack_remaining = 0.5
		attack_cooldown = definition.basic_interval
		animations.speed_scale = 1.0
		animations.play("Attack", 0.05)


func _in_attack_range(enemy: Node3D) -> bool:
	return global_position.distance_to(enemy.global_position) <= definition.basic_range


func _nearest_enemy_in_range() -> BasicSkeleton:
	var nearest: BasicSkeleton
	var distance := definition.basic_range
	for enemy: BasicSkeleton in get_tree().get_nodes_in_group("basic_skeletons"):
		var candidate := global_position.distance_to(enemy.global_position)
		if not enemy.dead and candidate <= distance:
			nearest = enemy
			distance = candidate
	return nearest


func take_damage(amount: int, can_kill: bool = true, attack_id: StringName = &"") -> void:
	if amount <= 0:
		return
	var previous_health := health
	health = maxi(0 if can_kill else 1, health - amount)
	var visual := model.get_node("Library") as CharacterVisual
	if visual != null and (health < previous_health or attack_id == &"basic"):
		visual.show_damage(previous_health - health, attack_id == &"basic")
	if health == 0:
		stop_combat()
		get_tree().call_group("basic_skeletons", "reset_combat")
		global_position = spawn_position
		velocity = Vector3.ZERO
		health = MAX_HEALTH
		respawned.emit()


func _animate_walk() -> void:
	var walking := horizontal_speed > 0.08 and is_on_floor()
	var clip := "Walk" if walking else "Idle"
	if animations.current_animation != clip:
		animations.play(clip, 0.2)
	animations.speed_scale = maxf(horizontal_speed / animation_walk_speed, 0.15) if walking else 1.0
