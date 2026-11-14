class_name CharacterVisual
extends Node3D
## Optional art adapter; every provider exposes the same gameplay animation names.

var class_id: String = ""
var model: Node3D
var animations: AnimationPlayer
var using_fallback: bool = false


func set_class(id: String) -> void:
	if id == class_id and is_instance_valid(model):
		return
	var definition := CharacterClasses.find_class(id)
	if definition == null:
		definition = CharacterClasses.find_class("warrior")
	class_id = definition.id
	_set_model(VisualAssets.scene(VisualAssets.MODELS[class_id]), class_id)


func set_skeleton() -> void:
	_set_model(VisualAssets.scene(VisualAssets.MODELS.skeleton), "skeleton")


func set_mannequin() -> void:
	var scene := VisualAssets.scene(VisualAssets.MODELS.mannequin)
	if scene == null:
		_set_model(null, "mannequin")
		return
	_clear_model()
	model = scene.instantiate()
	model.name = "Model"
	add_child(model)
	using_fallback = false
	animations = model.get_node("AnimationPlayer")


func _clear_model() -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()


func _set_model(scene: PackedScene, kind: String) -> void:
	_clear_model()
	var general := VisualAssets.scene(VisualAssets.GENERAL)
	var movement := VisualAssets.scene(VisualAssets.MOVEMENT)
	using_fallback = scene == null or general == null or movement == null
	var library: AnimationLibrary
	if using_fallback:
		var primitive := PrimitiveVisual.new()
		primitive.configure(kind)
		model = primitive
		library = primitive.animation_library()
	else:
		model = scene.instantiate()
		library = AnimationLibrary.new()
		_add_clip(library, general, "Idle_A", "Idle")
		_add_clip(library, movement, "Walking_A", "Walk")
		_add_clip(library, general, "Death_A", "Death", false)
		_add_attack(library)
	model.name = "Model"
	add_child(model)
	animations = AnimationPlayer.new()
	animations.name = "AnimationPlayer"
	model.add_child(animations)
	animations.add_animation_library("", library)
	animations.play("Idle")
	animations.advance(0)


func _add_clip(library: AnimationLibrary, source: PackedScene, source_name: String, name_in_game: String, looping: bool = true) -> void:
	var rig := source.instantiate()
	var source_player: AnimationPlayer = rig.get_node("AnimationPlayer")
	var animation: Animation = source_player.get_animation(source_name).duplicate()
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	library.add_animation(name_in_game, animation)
	rig.free()


func _add_attack(library: AnimationLibrary) -> void:
	# Keep the authored idle pose and animate a short right-hand weapon swing.
	var attack: Animation = library.get_animation("Idle").duplicate()
	attack.loop_mode = Animation.LOOP_NONE
	attack.length = 0.5
	for bone in ["upperarm.r", "lowerarm.r"]:
		var path := NodePath("Rig_Medium/Skeleton3D:" + bone)
		var track := attack.find_track(path, Animation.TYPE_ROTATION_3D)
		var rest: Quaternion = attack.track_get_key_value(track, 0)
		attack.remove_track(track)
		track = attack.add_track(Animation.TYPE_ROTATION_3D)
		attack.track_set_path(track, path)
		attack.rotation_track_insert_key(track, 0.0, rest)
		attack.rotation_track_insert_key(track, 0.15, rest * Quaternion(Vector3.RIGHT, -1.1))
		attack.rotation_track_insert_key(track, 0.25, rest * Quaternion(Vector3.RIGHT, 0.65))
		attack.rotation_track_insert_key(track, 0.5, rest)
	library.add_animation("Attack", attack)


func equip_weapon(kind: String) -> void:
	var hand: Node3D
	if using_fallback:
		hand = Node3D.new()
		(model as PrimitiveVisual).weapon_socket.add_child(hand)
	else:
		var skeleton: Skeleton3D = model.get_node("Rig_Medium/Skeleton3D")
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "handslot.r"
		skeleton.add_child(attachment)
		hand = attachment
	hand.name = "BasicWeapon"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("69492f")
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("c6d5df")
	steel.metallic = 0.7
	steel.roughness = 0.3
	var handle := CylinderMesh.new()
	handle.top_radius = 0.035
	handle.bottom_radius = 0.035
	handle.height = 1.55 if kind == "staff" else 0.22
	_weapon_part(hand, handle, wood, Vector3.ZERO)
	if kind == "staff":
		var gem := SphereMesh.new()
		gem.radius = 0.09
		gem.height = 0.18
		_weapon_part(hand, gem, steel, Vector3(0, 0.8, 0))
	else:
		var blade := PrismMesh.new()
		var length := 0.4 if kind == "dagger" else 0.75
		blade.size = Vector3(0.09, length, 0.035)
		_weapon_part(hand, blade, steel, Vector3(0, length * 0.5 + 0.1, 0))
		var guard := BoxMesh.new()
		guard.size = Vector3(0.23, 0.05, 0.07)
		_weapon_part(hand, guard, steel, Vector3(0, 0.1, 0))


func _weapon_part(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	parent.add_child(part)


func show_damage(amount: int, basic_attack: bool = false) -> void:
	var label := Label3D.new()
	label.name = "DamageFeedback"
	label.text = "%s\n%d" % [tr("COMBAT_BASIC_HIT"), amount] if basic_attack else str(amount)
	label.font_size = 48
	label.outline_size = 4
	label.pixel_size = 0.008
	label.modulate = Color("e75d4e")
	label.position = Vector3(0, 2.7, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", 3.5, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)
