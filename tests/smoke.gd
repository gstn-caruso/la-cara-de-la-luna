extends SceneTree
## Integration test: real key events, physics, imported animations and camera.
## godot --headless --path . --fixed-fps 60 --script res://tests/smoke.gd

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Keep this original mannequin regression test independent of saved characters.
	root.get_node("CharacterStore").characters.clear()
	root.get_node("CharacterStore").selected_character_id = ""
	var scene: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var player: CharacterBody3D = scene.get_node("Player")
	var camera: Camera3D = scene.get_node("Camera3D")
	var model: Node3D = player.get_node("Model")
	var animations: AnimationPlayer = model.get_node("Library/AnimationPlayer")
	var skeleton: Skeleton3D = model.get_node("Library/Armature/Skeleton3D")
	await _frames(30)
	_check(player.is_on_floor(), "The capsule rests on the floor")
	_check(absf(player.position.y) < 0.02, "The character origin stays at floor height")
	_check(animations.current_animation == "Idle", "The imported idle animation starts")
	for clip in ["Idle", "Walk"]:
		_check(animations.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s loops" % clip)

	# Both keyboard layouts must map to the same camera-relative directions.
	var cases := [
		[KEY_W, Vector2(0, -1)], [KEY_UP, Vector2(0, -1)],
		[KEY_S, Vector2(0, 1)], [KEY_DOWN, Vector2(0, 1)],
		[KEY_A, Vector2(-1, 0)], [KEY_LEFT, Vector2(-1, 0)],
		[KEY_D, Vector2(1, 0)], [KEY_RIGHT, Vector2(1, 0)],
	]
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	for entry in cases:
		var start := player.position
		_key(entry[0], true)
		await _frames(60)
		var axes: Vector2 = entry[1]
		var expected := (right.normalized() * axes.x + back.normalized() * axes.y).normalized()
		var actual := Vector3(player.velocity.x, 0, player.velocity.z)
		_check(actual.normalized().dot(expected) > 0.99, "Key %s moves relative to the camera" % entry[0])
		_check(absf(actual.length() - player.walk_speed) < 0.01, "Walking reaches configured speed")
		_check(player.position.distance_to(start) > 1.0, "Physics moves the capsule")
		_check((-model.global_basis.z).dot(expected) > 0.99, "The mannequin turns toward movement")
		_check(animations.current_animation == "Walk", "Movement selects the imported walk")
		_check(player.is_on_floor() and absf(player.position.y) < 0.02, "Walking maintains floor contact")
		_key(entry[0], false)
		await _frames(30)
		_check(player.velocity.length() < 0.01, "Releasing the key stops movement")
		_check(animations.current_animation == "Idle", "Stopping returns to idle")

	for horizontal in [KEY_A, KEY_D]:
		for vertical in [KEY_W, KEY_S]:
			_key(horizontal, true)
			_key(vertical, true)
			await _frames(30)
			_check(absf(player.velocity.length() - player.walk_speed) < 0.01, "Diagonals do not increase speed")
			_key(horizontal, false)
			_key(vertical, false)
			await _frames(30)

	_key(KEY_W, true)
	_key(KEY_S, true)
	await _frames(30)
	_check(player.velocity.length() < 0.01, "Opposing directions cancel")
	_key(KEY_S, false)
	await _frames(30)
	var bone := skeleton.find_bone("thigh_l")
	_check(bone >= 0, "The imported skeleton includes leg bones")
	var pose := skeleton.get_bone_pose_rotation(bone)
	await _frames(10)
	_check(pose.angle_to(skeleton.get_bone_pose_rotation(bone)) > 0.02, "The walk animates the skeleton")
	await _frames(120)
	_check(animations.is_playing() and animations.current_animation == "Walk", "Walking continues across loop boundaries")
	_key(KEY_W, false)
	await _frames(60)
	var desired_focus: Vector3 = player.global_position + Vector3.UP * camera.focus_height
	_check(camera.global_position.distance_to(desired_focus + camera.offset) < 0.03, "The camera catches up after movement")
	_check(player.velocity.length() < 0.01 and animations.current_animation == "Idle", "The scene settles in idle")
	if failures == 0:
		print("PASS: keyboard, directions, diagonal speed, floor, facing, animation loops, skeleton and camera.")
	quit(0 if failures == 0 else 1)


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
