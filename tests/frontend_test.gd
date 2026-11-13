extends SceneTree

var failures := 0
var test_path := "user://frontend_test_%s" % Time.get_ticks_usec()
var frontend: Node
var store: Node
var localization: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	store = root.get_node("CharacterStore")
	localization = root.get_node("Localization")
	store.storage_path = test_path + ".json"
	store.load_characters()
	localization.storage_path = test_path + ".cfg"
	localization.set_language("en")
	frontend = load("res://scenes/frontend.tscn").instantiate()
	root.add_child(frontend)
	current_scene = frontend
	await _frames(3)
	_check(frontend.screen == frontend.Screen.TITLE, "The title appears first")
	_check(_button("PlayButton").has_focus(), "Play receives initial keyboard focus")
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	root.push_input(confirm)
	confirm = confirm.duplicate()
	confirm.pressed = false
	root.push_input(confirm)
	await _frames(2)
	_check(_button("EnterWorldButton").disabled, "Empty rosters cannot enter the world")
	_check(_button("DeleteCharacterButton").disabled, "Empty rosters cannot delete")
	_press("NewCharacterButton")
	await _frames(2)
	_check(frontend.draft_class == "" and _button("CreateButton").disabled, "Creation starts without a class")
	frontend.name_input.text = "Éowyn"
	frontend.name_input.text_changed.emit("Éowyn")
	_press("Class_warrior")
	await _frames(2)
	_check(not _button("CreateButton").disabled, "A valid draft enables Create")
	localization.set_language("es")
	await _frames(3)
	var settings := ConfigFile.new()
	_check(settings.load(localization.storage_path) == OK and settings.get_value("interface", "language") == "es", "The language preference is persisted")
	TranslationServer.set_locale("en")
	var restored_language: Node = load("res://scripts/localization.gd").new()
	restored_language.storage_path = localization.storage_path
	root.add_child(restored_language)
	_check(TranslationServer.get_locale().begins_with("es"), "A new language service restores the saved preference")
	restored_language.queue_free()
	await _frames(3)
	_check(frontend.draft_name == "Éowyn" and frontend.draft_class == "warrior", "Changing language preserves the draft")
	_check(_button("CreateButton").text == "Crear", "The creation screen switches to Spanish")
	_press("CreateButton")
	await _frames(2)
	_check(store.characters.size() == 1, "Create saves a character")
	_check(not _button("EnterWorldButton").disabled, "A selected character can enter")
	_press("NewCharacterButton")
	await _frames(2)
	frontend.name_input.text = "Discarded"
	frontend.name_input.text_changed.emit("Discarded")
	_press("Class_rogue")
	await _frames(2)
	_press("CancelCreationButton")
	await _frames(2)
	_check(store.characters.size() == 1 and frontend.draft_name.is_empty(), "Cancel discards the unsaved draft")
	_press("DeleteCharacterButton")
	_check(frontend.delete_dialog.dialog_text.contains("Éowyn"), "Deletion names its target")
	frontend.delete_dialog.canceled.emit()
	frontend.delete_dialog.hide()
	_check(store.characters.size() == 1, "Canceling deletion preserves the character")

	# Every catalog entry must resolve in each supported locale.
	var csv := FileAccess.open("res://i18n/messages.csv", FileAccess.READ)
	csv.get_csv_line()
	var messages: Dictionary = {}
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if not row[0].is_empty():
			messages[row[0]] = {"en": row[1], "es": row[2]}
	for locale in ["en", "es"]:
		localization.set_language(locale)
		await _frames(2)
		for key: String in messages:
			_check(TranslationServer.translate(key) == messages[key][locale], "Catalog key resolves: " + key + " / " + locale)
	localization.set_language("es")
	await _frames(2)
	_press("EnterWorldButton")
	await _frames(5)
	var world := current_scene
	_check(world.name == "MotionStudy", "Enter World opens the walking scene")
	_check(world.get_node("Overlay/Layout/Content/Title").text == "Éowyn", "The selected character identity reaches the world")
	var player: Node = world.get_node("Player")
	var visual: Node = player.get_node("Model/Library")
	_check(visual is CharacterVisual and visual.class_id == "warrior", "The selected KayKit model reaches the world")
	Input.action_press("move_forward")
	await _frames(60)
	_check(player.position.length() > 1.0 and visual.animations.current_animation == "Walk", "The selected character walks and animates")
	Input.action_release("move_forward")
	await _frames(20)
	_check(visual.animations.current_animation == "Idle", "The selected character returns to idle")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await _frames(5)
	frontend = current_scene
	_check(frontend.name == "Frontend" and frontend.screen == frontend.Screen.ROSTER, "Escape returns directly to the roster")
	if frontend.name != "Frontend":
		quit(1)
		return
	escape.pressed = false
	root.push_input(escape)
	_press("DeleteCharacterButton")
	frontend.delete_dialog.confirmed.emit()
	await _frames(3)
	_check(store.characters.is_empty(), "Confirmed deletion restores the empty roster")
	_check(_button("EnterWorldButton").disabled, "Entry is disabled after the final deletion")
	for id in ["rogue", "mage"]:
		_check(store.create_character("Preview " + id, id), "Additional classes can be created")
		frontend._show_roster()
		await _frames(2)
		_press("EnterWorldButton")
		await _frames(4)
		var alternate: Node = current_scene.get_node("Player/Model/Library")
		_check(alternate.class_id == id and alternate.animations.is_playing(), "Each class uses its matching animated model")
		var start: Vector3 = current_scene.get_node("Player").position
		Input.action_press("move_right")
		await _frames(40)
		Input.action_release("move_right")
		_check(current_scene.get_node("Player").position.distance_to(start) > 0.5, "Each class can move in the world")
		var back := InputEventKey.new()
		back.keycode = KEY_ESCAPE
		back.pressed = true
		root.push_input(back)
		await _frames(4)
		frontend = current_scene
		back.pressed = false
		root.push_input(back)
	for index in range(6):
		store.create_character("Slot %d" % index, "warrior")
	frontend._show_roster()
	await _frames(2)
	_check(_button("NewCharacterButton").disabled, "The full roster disables creation")
	for suffix in [".json", ".json.bak", ".json.tmp", ".cfg"]:
		DirAccess.remove_absolute(test_path + suffix)
	if failures == 0:
		print("PASS: title, roster, creation, cancellation, deletion, EN/ES, world entry, animations and return.")
	quit(0 if failures == 0 else 1)


func _button(node_name: String) -> Button:
	return frontend.find_child(node_name, true, false) as Button


func _press(node_name: String) -> void:
	var button := _button(node_name)
	_check(button != null and not button.disabled, "Button is available: " + node_name)
	if button != null and not button.disabled:
		button.pressed.emit()


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
