class_name BasicSkeleton
extends CharacterBody3D
## A starter enemy: detect nearby players, fight, leash home, die and respawn.

signal defeated(enemy: BasicSkeleton, source: Node3D, attack_id: StringName)

const MAX_HEALTH: int = 32
const DAMAGE: int = 5
const ATTACK_INTERVAL: float = 1.4
const ATTACK_RANGE: float = 1.4
const AGGRO_RADIUS: float = 2.5
const LEASH_DISTANCE: float = 9.0
const RESPAWN_SECONDS: float = 6.0

var health: int = MAX_HEALTH
var dead: bool = false
var attacker: CharacterBody3D
var home: Vector3
var visual: CharacterVisual
var health_label: Label
var health_bar: ProgressBar
var name_label: Label
var nameplate: VBoxContainer
var selection: MeshInstance3D
var cooldown: float = 0.0
var attack_remaining: float = 0.0
var hit_pending: bool = false
var respawn_remaining: float = 0.0


func _ready() -> void:
	add_to_group("basic_skeletons")
	home = global_position
	collision_layer = 2
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.7
	var collider := CollisionShape3D.new()
	collider.position.y = 0.85
	collider.shape = shape
	add_child(collider)
	visual = CharacterVisual.new()
	visual.name = "Visual"
	add_child(visual)
	visual.set_skeleton()
	_build_nameplate()
	selection = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.49
	ring.rings = 24
	ring.ring_segments = 8
	selection.mesh = ring
	selection.position.y = 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d78a33")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection.material_override = material
	selection.visible = false
	add_child(selection)
	_update_label()


func _build_nameplate() -> void:
	# A screen-space bar stays readable at every camera zoom level.
	var layer := CanvasLayer.new()
	layer.name = "EnemyHealthOverlay"
	add_child(layer)
	nameplate = VBoxContainer.new()
	nameplate.name = "EnemyNameplate"
	nameplate.custom_minimum_size.x = 160
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_theme_constant_override("separation", 4)
	layer.add_child(nameplate)
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color("302a28"))
	name_label.add_theme_constant_override("outline_size", 4)
	nameplate.add_child(name_label)
	health_bar = ProgressBar.new()
	health_bar.name = "EnemyHealth"
	health_bar.custom_minimum_size.y = 24
	health_bar.max_value = MAX_HEALTH
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("453a37")
	background.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b44642")
	fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", fill)
	nameplate.add_child(health_bar)
	health_label = Label.new()
	health_label.name = "Text"
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.add_theme_font_size_override("font_size", 13)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_bar.add_child(health_label)
	health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var anchor := global_position + Vector3.UP * 2.1
	nameplate.visible = not dead and camera != null and not camera.is_position_behind(anchor)
	if nameplate.visible:
		nameplate.position = camera.unproject_position(anchor) - Vector2(nameplate.size.x * 0.5, nameplate.size.y)


func _physics_process(delta: float) -> void:
	if dead:
		respawn_remaining -= delta
		if respawn_remaining <= 0.0:
			_respawn()
		return
	cooldown = maxf(0.0, cooldown - delta)
	if not is_instance_valid(attacker):
		_acquire_attacker()
	if is_instance_valid(attacker):
		if global_position.distance_to(home) > LEASH_DISTANCE or attacker.global_position.distance_to(home) > LEASH_DISTANCE:
			reset_combat()
		else:
			_fight(delta)
	else:
		_play("Idle")
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()


func _acquire_attacker() -> void:
	for player: CharacterBody3D in get_tree().get_nodes_in_group("player_characters"):
		if global_position.distance_to(player.global_position) <= AGGRO_RADIUS:
			attacker = player
			return


func _fight(delta: float) -> void:
	var offset := attacker.global_position - global_position
	var distance := offset.length()
	visual.rotation.y = atan2(offset.x, offset.z)
	velocity.x = 0.0
	velocity.z = 0.0
	if attack_remaining > 0.0:
		attack_remaining = maxf(0.0, attack_remaining - delta)
		if hit_pending and attack_remaining <= 0.28:
			hit_pending = false
			if distance <= ATTACK_RANGE:
				# This starter opponent lets the player practice without dying.
				attacker.take_damage(DAMAGE, false, &"basic")
		return
	if distance > ATTACK_RANGE - 0.15:
		var direction := Vector3(offset.x, 0, offset.z).normalized()
		velocity.x = direction.x * 1.2
		velocity.z = direction.z * 1.2
		_play("Walk")
	elif cooldown <= 0.0:
		cooldown = ATTACK_INTERVAL
		attack_remaining = 0.5
		hit_pending = true
		_play("Attack")
	else:
		_play("Idle")


func take_damage(amount: int, source: CharacterBody3D, attack_id: StringName = &"basic") -> void:
	if dead or amount <= 0 or not is_instance_valid(source):
		return
	attacker = source
	health = maxi(0, health - amount)
	visual.show_damage(amount, attack_id == &"basic")
	_update_label()
	if health == 0:
		dead = true
		nameplate.hide()
		velocity = Vector3.ZERO
		attacker = null
		hit_pending = false
		set_collision_layer_value(2, false)
		selection.hide()
		_play("Death")
		respawn_remaining = RESPAWN_SECONDS
		defeated.emit(self, source, attack_id)


func reset_combat() -> void:
	if dead:
		return
	attacker = null
	health = MAX_HEALTH
	velocity = Vector3.ZERO
	cooldown = 0.0
	attack_remaining = 0.0
	hit_pending = false
	global_position = home
	_play("Idle")
	_update_label()


func _respawn() -> void:
	dead = false
	set_collision_layer_value(2, true)
	reset_combat()


func set_selected(selected: bool) -> void:
	selection.visible = selected and not dead


func _play(clip: String) -> void:
	if visual.animations.current_animation != clip:
		visual.animations.play(clip, 0.1)


func _update_label() -> void:
	name_label.text = tr("ENEMY_SKELETON")
	health_bar.value = health
	health_label.text = tr("COMBAT_HEALTH") % [health, MAX_HEALTH]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_label()
