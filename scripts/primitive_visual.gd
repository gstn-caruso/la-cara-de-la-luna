class_name PrimitiveVisual
extends Node3D
## Native geometry and animation keep the complete game playable without art packs.

var weapon_socket: Node3D


func configure(kind: String) -> void:
	var colors := {"warrior": "718799", "rogue": "3c7757", "mage": "7958a6", "mannequin": "808887", "skeleton": "e0d4b4"}
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colors.get(kind, "808887"))
	material.roughness = 0.85
	var bone := kind == "skeleton"
	_box(self, "Torso", Vector3(0, 1.13, 0), Vector3(0.44, 0.48, 0.23), material)
	_box(self, "Head", Vector3(0, 1.65, 0), Vector3(0.36, 0.38, 0.32), material)
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color("211f29")
	for side in [-1.0, 1.0]:
		_box(self, "Eye", Vector3(side * 0.085, 1.7, 0.165), Vector3(0.065, 0.065, 0.015), eyes)
		var suffix := "Left" if side < 0 else "Right"
		var arm := Node3D.new()
		arm.name = "Arm" + suffix
		arm.position = Vector3(side * 0.3, 1.35, 0)
		add_child(arm)
		_box(arm, "Limb", Vector3(0, -0.25, 0), Vector3(0.09 if bone else 0.16, 0.5, 0.15), material)
		if side > 0:
			weapon_socket = Node3D.new()
			weapon_socket.name = "WeaponSocket"
			weapon_socket.position.y = -0.5
			arm.add_child(weapon_socket)
		var leg := Node3D.new()
		leg.name = "Leg" + suffix
		leg.position = Vector3(side * 0.13, 0.88, 0)
		add_child(leg)
		_box(leg, "Limb", Vector3(0, -0.4, 0), Vector3(0.1 if bone else 0.18, 0.8, 0.2), material)
	if bone:
		for y in [1.0, 1.13, 1.26]:
			_box(self, "Rib", Vector3(0, y, 0.13), Vector3(0.48, 0.045, 0.07), material)
	elif kind == "mage":
		var hat := CylinderMesh.new()
		hat.top_radius = 0.0
		hat.bottom_radius = 0.29
		hat.height = 0.5
		var instance := MeshInstance3D.new()
		instance.mesh = hat
		instance.material_override = material
		instance.position.y = 2.05
		add_child(instance)


func animation_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for clip in ["Idle", "Walk", "Attack", "Death"]:
		var animation := Animation.new()
		animation.length = 0.7 if clip == "Walk" else (1.3 if clip == "Idle" else 0.5)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Idle", "Walk"] else Animation.LOOP_NONE
		for limb in ["ArmLeft", "ArmRight", "LegLeft", "LegRight"]:
			var amount := 0.55 if limb.begins_with("Leg") else 0.4
			if limb.ends_with("Right"):
				amount = -amount
			if clip == "Walk":
				_track(animation, limb + ":rotation", [0.0, 0.35, 0.7], [Vector3(amount, 0, 0), Vector3(-amount, 0, 0), Vector3(amount, 0, 0)])
			elif clip == "Attack" and limb == "ArmRight":
				_track(animation, limb + ":rotation", [0.0, 0.15, 0.25, 0.5], [Vector3.ZERO, Vector3(-1.4, 0, 0), Vector3(0.7, 0, 0), Vector3.ZERO])
			else:
				_track(animation, limb + ":rotation", [0.0], [Vector3.ZERO])
		_track(animation, ".:rotation", [0.0, animation.length], [Vector3.ZERO, Vector3(-PI / 2, 0, 0) if clip == "Death" else Vector3.ZERO])
		library.add_animation(clip, animation)
	return library


func _track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	for index in range(times.size()):
		animation.track_insert_key(track, times[index], values[index])


func _box(parent: Node3D, node_name: String, offset: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	parent.add_child(instance)
