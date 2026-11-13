extends Node3D
## Original low poly set dressing, built entirely with native Godot geometry.

var preview: Node3D
var fire: OmniLight3D
var time: float = 0.0
var stones := StandardMaterial3D.new()
var timber := StandardMaterial3D.new()
var leaves := StandardMaterial3D.new()


func _ready() -> void:
	stones.albedo_color = Color("4a5358")
	stones.roughness = 1.0
	timber.albedo_color = Color("3b302c")
	leaves.albedo_color = Color("263d40")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("17232f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9daecb")
	environment.ambient_light_energy = 0.55
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, -38, 0)
	moon.light_color = Color("b7cfe7")
	moon.light_energy = 0.8
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30
	add_child(moon)
	var key := OmniLight3D.new()
	key.position = Vector3(0, 3.5, 3.0)
	key.light_color = Color("ffe1ae")
	key.light_energy = 2.0
	key.omni_range = 7.0
	add_child(key)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.6, 7.8)
	camera.fov = 33
	camera.h_offset = 0.55
	add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.current = true
	_cylinder("Clearing", Vector3(0, -0.24, -1), 10, 0.45, _material("343d37"), 16)
	_cylinder("Path", Vector3(0, -0.015, 0), 3.5, 0.04, _material("4c4d40"), 12)
	_cylinder("PlatformRim", Vector3(0, 0.045, 0), 1.24, 0.12, _material("70634c"), 12)
	_cylinder("Platform", Vector3(0, 0.115, 0), 1.19, 0.06, _material("606765"), 12)
	for index in range(12):
		var angle := index * TAU / 12.0
		_box("PlatformMark", Vector3(sin(angle) * 1.05, 0.147, cos(angle) * 1.05), Vector3(0.04, 0.006, 0.11), _material("ae9b6c"), Vector3(0, angle, 0))
	_tent(Vector3(-3.4, 0, -2.8))
	for position in [Vector3(-5, 0, -3), Vector3(-4, 0, -6), Vector3(-1.8, 0, -6.3), Vector3(1.0, 0, -7), Vector3(3, 0, -5.5), Vector3(5.0, 0, -4), Vector3(6, 0, -1.5), Vector3(-6, 0, 1.0)]:
		_tree(position, 2.8 + absf(position.x) * 0.15)
	for index in range(16):
		var angle := index * 2.399
		var radius := 4.0 + float(index % 3) * 0.7
		_rock(Vector3(sin(angle) * radius, 0.15, cos(angle) * radius - 1), Vector3(0.5, 0.35, 0.4), angle)
	for index in range(12):
		var position := Vector3(-4.2 + index * 0.72, 0.02, -4.1 + sin(index * 0.8) * 0.35)
		_rock(position, Vector3(0.27, 0.12, 0.24), index)
	_campfire(Vector3(-2.4, 0, 0.8))
	_box("Crate", Vector3(2.2, 0.32, -1.6), Vector3(0.66, 0.64, 0.66), _material("68533c"), Vector3(0, 0.3, 0))
	_box("CrateBand", Vector3(2.2, 0.49, -1.6), Vector3(0.69, 0.08, 0.69), timber, Vector3(0, 0.3, 0))
	_box("Bedroll", Vector3(-2.5, 0.1, -1.5), Vector3(0.65, 0.14, 1.45), _material("77755a"), Vector3(0, -0.2, 0))
	preview = CharacterVisual.new()
	preview.name = "CharacterPreview"
	preview.position = Vector3(0, 0.15, 0)
	preview.rotation.y = 0.25
	add_child(preview)
	set_class("")


func set_class(class_id: String) -> void:
	var definition := CharacterClasses.find_class(class_id)
	if definition == null:
		definition = CharacterClasses.find_class("warrior")
	preview.set_class(definition.id)


func _process(delta: float) -> void:
	time += delta
	if is_instance_valid(fire):
		fire.light_energy = 2.5 + sin(time * 8.0) * 0.15 + sin(time * 13.0) * 0.12


func _material(hex: String, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.95
	if glow:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _mesh(node_name: String, position: Vector3, mesh: Mesh, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	add_child(instance)
	return instance


func _box(node_name: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(node_name, position, mesh, material, rotation)


func _cylinder(node_name: String, position: Vector3, radius: float, height: float, material: Material, segments: int = 8) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	_mesh(node_name, position, mesh, material)


func _rock(position: Vector3, size: Vector3, angle: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 5
	mesh.rings = 2
	var rock := _mesh("Rock", position, mesh, stones, Vector3(0.15, angle, 0.2))
	rock.scale = size


func _tree(position: Vector3, height: float) -> void:
	_cylinder("Trunk", position + Vector3.UP * height * 0.4, 0.14, height * 0.8, timber)
	for index in range(3):
		var cone := CylinderMesh.new()
		cone.top_radius = 0
		cone.bottom_radius = (1.0 - index * 0.2) * height * 0.35
		cone.height = height * 0.55
		cone.radial_segments = 6
		_mesh("Pine", position + Vector3.UP * height * (0.48 + index * 0.23), cone, leaves, Vector3(0, index * 0.3, 0))


func _tent(position: Vector3) -> void:
	var cloth := _material("8b7350")
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-1.2, 0, 1), Vector3(0, 1.65, 1), Vector3(1.2, 0, 1), Vector3(-1.2, 0, -1.2), Vector3(0, 1.65, -1.2), Vector3(1.2, 0, -1.2)]
	for index in [0, 3, 1, 1, 3, 4, 1, 4, 2, 2, 4, 5, 3, 5, 4]:
		tool.add_vertex(points[index])
	tool.generate_normals()
	_mesh("TentCanvas", position, tool.commit(), cloth)
	for z in [1.04, -1.24]:
		_box("TentPole", position + Vector3(0, 0.85, z), Vector3(0.07, 1.8, 0.07), timber)
	_box("TentRidge", position + Vector3(0, 1.65, -0.1), Vector3(0.08, 0.08, 2.5), timber)
	_box("TentInterior", position + Vector3(0, 0.02, -0.1), Vector3(2.3, 0.03, 2.1), _material("252a28"))


func _campfire(position: Vector3) -> void:
	for index in range(9):
		var angle := index * TAU / 9.0
		_rock(position + Vector3(sin(angle) * 0.48, 0.08, cos(angle) * 0.48), Vector3(0.23, 0.18, 0.2), angle)
	_box("Firewood", position + Vector3(0, 0.13, 0), Vector3(0.8, 0.15, 0.16), timber, Vector3(0, 0.6, 0))
	_box("Firewood", position + Vector3(0, 0.2, 0), Vector3(0.7, 0.14, 0.16), timber, Vector3(0, -0.7, 0))
	for index in range(3):
		var flame := CylinderMesh.new()
		flame.top_radius = 0
		flame.bottom_radius = 0.22 - index * 0.035
		flame.height = 0.55 - index * 0.07
		flame.radial_segments = 5
		_mesh("Flame", position + Vector3((index - 1) * 0.13, 0.45, 0), flame, _material("ffb24e" if index == 1 else "db6c32", true), Vector3(0, index, 0.15 * (index - 1)))
	fire = OmniLight3D.new()
	fire.position = position + Vector3.UP * 0.8
	fire.light_color = Color("ffb366")
	fire.omni_range = 5.0
	fire.light_energy = 2.5
	add_child(fire)
