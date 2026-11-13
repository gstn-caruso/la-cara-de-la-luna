extends Node3D
## One shared camp; rebuilding the small UI keeps translated text consistent.

enum Screen { TITLE, ROSTER, CREATE }

var screen: Screen = Screen.TITLE
var draft_name: String = ""
var draft_class: String = ""
var ui_root: Control
var theme: Theme
var name_input: LineEdit
var create_button: Button
var validation_label: Label
var deletion_id: String = ""
var delete_dialog: ConfirmationDialog
var initialized: bool = false
var rebuilding: bool = false

@onready var camp: Node3D = $Camp


func _ready() -> void:
	theme = _make_theme()
	var overlay := CanvasLayer.new()
	overlay.name = "Interface"
	add_child(overlay)
	ui_root = Control.new()
	ui_root.name = "Screens"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.theme = theme
	overlay.add_child(ui_root)
	if CharacterStore.return_to_roster:
		screen = Screen.ROSTER
		CharacterStore.return_to_roster = false
	initialized = true
	_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and initialized and is_inside_tree():
		_render.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(delete_dialog) and delete_dialog.visible:
			delete_dialog.hide()
		elif screen == Screen.CREATE:
			_show_roster()
		elif screen == Screen.ROSTER:
			screen = Screen.TITLE
			_render()
		get_viewport().set_input_as_handled()


func _render() -> void:
	if rebuilding or not is_instance_valid(ui_root) or not is_inside_tree():
		return
	rebuilding = true
	for child in ui_root.get_children():
		ui_root.remove_child(child)
		child.queue_free()
	name_input = null
	create_button = null
	validation_label = null
	delete_dialog = null
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { float edge = (1.0-smoothstep(0.0,0.4,UV.x))*0.45 + smoothstep(0.5,1.0,UV.x)*0.4 + smoothstep(0.65,1.0,UV.y)*0.4; COLOR=vec4(0.015,0.025,0.035,edge); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	ui_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	ui_root.add_child(margin)
	var layout := _column(margin, 16)
	var header := _row(layout, 16)
	_label(header, "APP_NAME", 24, Color("d7bd82"))
	_label(header, "FRONTEND_EYEBROW", 11, Color("9ca9b0")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(Localization.make_selector())
	var body := _row(layout, 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var info := _column(body, 14)
	info.custom_minimum_size.x = 235
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(space)
	var side := _column(body, 12)
	side.custom_minimum_size.x = 320
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if screen == Screen.TITLE:
		_title(info, side)
	elif screen == Screen.ROSTER:
		_roster(info, side)
	else:
		_creation(info, side)
	var footer := _row(layout, 16)
	_label(footer, "CAMP_NAME", 12, Color("bdab87")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var version := _label(footer, "", 11, Color("9ca9b0"))
	version.text = tr("BUILD_VERSION") % FileAccess.get_file_as_string("res://version.txt").strip_edges()
	_label(footer, "NAVIGATION_HINT", 11, Color("9ca9b0"))
	rebuilding = false
	if is_instance_valid(name_input):
		_focus_name.call_deferred()
		name_input.caret_column = name_input.text.length()
	else:
		_focus_first.call_deferred()


func _focus_name() -> void:
	if is_instance_valid(name_input) and name_input.is_inside_tree():
		name_input.grab_focus()


func _title(info: VBoxContainer, side: VBoxContainer) -> void:
	camp.preview.visible = true
	camp.set_class("warrior")
	_label(info, "TITLE_KICKER", 12, Color("d7bd82"))
	var wordmark := _label(info, "APP_NAME", 44, Color("f5ead3"), true)
	wordmark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wordmark.custom_minimum_size.x = 235
	_wrapped(info, "TITLE_DESCRIPTION", 17, 235)
	var panel := _panel(side)
	_label(panel, "TITLE_WELCOME", 26, Color("f5ead3"), true)
	_wrapped(panel, "TITLE_SUBTITLE", 14, 280)
	_button(panel, "PLAY", _show_roster, true).name = "PlayButton"
	_button(panel, "QUIT", func() -> void: get_tree().quit()).name = "QuitButton"


func _roster(info: VBoxContainer, side: VBoxContainer) -> void:
	var selected := CharacterStore.selected_character()
	camp.preview.visible = not selected.is_empty()
	_label(info, "ROSTER_KICKER", 12, Color("d7bd82"))
	if selected.is_empty():
		_label(info, "ROSTER_EMPTY_TITLE", 32, Color("f5ead3"), true)
		_wrapped(info, "ROSTER_EMPTY_DESCRIPTION", 15, 235)
	else:
		var definition := CharacterClasses.find_class(selected.class_id)
		camp.set_class(selected.class_id)
		var character_label := _label(info, "", 32, Color("f5ead3"), true)
		character_label.text = selected.name
		character_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		character_label.custom_minimum_size.x = 235
		character_label.clip_text = true
		character_label.tooltip_text = selected.name
		_label(info, definition.name_key, 20, Color("d7bd82"))
		_label(info, definition.role_key, 12)
		_wrapped(info, definition.description_key, 15, 235)
	var panel := _panel(side)
	_label(panel, "ROSTER_TITLE", 26, Color("f5ead3"), true)
	var count := _label(panel, "", 12)
	count.text = tr("ROSTER_COUNT") % [CharacterStore.characters.size(), CharacterStore.MAX_CHARACTERS]
	var scroll := ScrollContainer.new()
	scroll.name = "CharacterList"
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = 190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var list := _column(scroll, 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if CharacterStore.characters.is_empty():
		_wrapped(list, "ROSTER_EMPTY_LIST", 14, 278)
	for character in CharacterStore.characters:
		var definition := CharacterClasses.find_class(character.class_id)
		var row := _button(list, "", _select.bind(character.id), character.id == CharacterStore.selected_character_id)
		row.name = "Character_" + str(character.id)
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.text = character.name + "\n" + tr(definition.name_key)
		row.custom_minimum_size.y = 56
		row.clip_text = true
		row.tooltip_text = character.name
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var enter := _button(panel, "ENTER_WORLD", _on_enter_world_pressed, true)
	enter.name = "EnterWorldButton"
	enter.disabled = selected.is_empty() or not CharacterStore.can_write
	var create := _button(panel, "CREATE_CHARACTER", _show_creation)
	create.name = "NewCharacterButton"
	create.disabled = CharacterStore.characters.size() >= CharacterStore.MAX_CHARACTERS or not CharacterStore.can_write
	if CharacterStore.characters.size() >= CharacterStore.MAX_CHARACTERS:
		_label(panel, "ERROR_ROSTER_FULL", 12)
	var actions := _row(panel, 8)
	_button(actions, "BACK", func() -> void:
		screen = Screen.TITLE
		_render()
	).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var delete := _button(actions, "DELETE", _confirm_delete)
	delete.name = "DeleteCharacterButton"
	delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete.disabled = selected.is_empty() or not CharacterStore.can_write
	if not CharacterStore.error_key.is_empty():
		_wrapped(panel, CharacterStore.error_key, 13, 278, Color("efb4a0"))
		if not CharacterStore.can_write:
			_button(panel, "RETRY", func() -> void:
				CharacterStore.load_characters()
				_render()
			)


func _creation(info: VBoxContainer, side: VBoxContainer) -> void:
	_label(info, "CREATE_KICKER", 12, Color("d7bd82"))
	var definition := CharacterClasses.find_class(draft_class)
	camp.preview.visible = definition != null
	if definition == null:
		_label(info, "CLASS_CHOOSE_TITLE", 32, Color("f5ead3"), true)
		_wrapped(info, "CLASS_CHOOSE_DESCRIPTION", 15, 235)
	else:
		camp.set_class(draft_class)
		_label(info, definition.name_key, 36, Color("f5ead3"), true)
		_label(info, definition.role_key, 12, Color("d7bd82"))
		_wrapped(info, definition.description_key, 15, 235)
	var panel := _panel(side)
	_label(panel, "CREATE_TITLE", 26, Color("f5ead3"), true)
	_label(panel, "CHARACTER_NAME", 12, Color("d7bd82"))
	name_input = LineEdit.new()
	name_input.name = "CharacterName"
	name_input.text = draft_name
	name_input.placeholder_text = tr("NAME_PLACEHOLDER")
	name_input.custom_minimum_size.y = 44
	name_input.max_length = 64
	panel.add_child(name_input)
	name_input.text_changed.connect(func(value: String) -> void:
		draft_name = value
		_validate_draft()
	)
	name_input.text_submitted.connect(func(_value: String) -> void:
		if not create_button.disabled:
			_create_character()
	)
	_label(panel, "CHARACTER_CLASS", 12, Color("d7bd82"))
	for character_class: CharacterClass in CharacterClasses.ALL:
		var button := _button(panel, character_class.name_key, _choose_class.bind(character_class.id), draft_class == character_class.id)
		button.name = "Class_" + character_class.id
	validation_label = _wrapped(panel, "", 12, 278, Color("efb4a0"))
	validation_label.custom_minimum_size.y = 36
	create_button = _button(panel, "CREATE", _create_character, true)
	create_button.name = "CreateButton"
	_button(panel, "CANCEL", _show_roster).name = "CancelCreationButton"
	_validate_draft()


func _validate_draft() -> void:
	var error := CharacterStore.validate_creation(draft_name, draft_class)
	create_button.disabled = not error.is_empty()
	validation_label.text = tr(error) if not error.is_empty() else tr("CREATE_READY")
	validation_label.add_theme_color_override("font_color", Color("b5c9b3") if error.is_empty() else Color("c7b8a6"))


func _show_roster() -> void:
	draft_name = ""
	draft_class = ""
	screen = Screen.ROSTER
	_render()


func _show_creation() -> void:
	if not CharacterStore.can_write or CharacterStore.characters.size() >= CharacterStore.MAX_CHARACTERS:
		return
	draft_name = ""
	draft_class = ""
	screen = Screen.CREATE
	_render()


func _choose_class(id: String) -> void:
	draft_class = id
	_render()


func _create_character() -> void:
	if CharacterStore.create_character(draft_name, draft_class):
		_show_roster()
	else:
		validation_label.text = tr(CharacterStore.error_key)


func _select(id: String) -> void:
	CharacterStore.select_character(id)
	_render()


func _confirm_delete() -> void:
	var character := CharacterStore.selected_character()
	if character.is_empty():
		return
	deletion_id = character.id
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.name = "DeleteConfirmation"
	delete_dialog.theme = theme
	delete_dialog.title = tr("DELETE_TITLE")
	delete_dialog.dialog_text = tr("DELETE_CONFIRM") % character.name
	delete_dialog.get_label().auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	delete_dialog.ok_button_text = tr("DELETE")
	delete_dialog.cancel_button_text = tr("CANCEL")
	ui_root.add_child(delete_dialog)
	delete_dialog.confirmed.connect(func() -> void:
		CharacterStore.delete_character(deletion_id)
		_render()
	)
	delete_dialog.popup_centered(Vector2i(440, 180))
	delete_dialog.get_cancel_button().grab_focus()


func _on_enter_world_pressed() -> void:
	if not CharacterStore.selected_character().is_empty():
		_load_world.call_deferred()


func _load_world() -> void:
	if get_tree().change_scene_to_file("res://scenes/main.tscn") != OK:
		CharacterStore.error_key = "ERROR_ENTER_WORLD"
		_render()


func _focus_first() -> void:
	if not is_inside_tree():
		return
	var preferred_name := "PlayButton" if screen == Screen.TITLE else "Character_" + CharacterStore.selected_character_id
	var preferred := find_child(preferred_name, true, false) as Button
	if preferred == null and screen == Screen.ROSTER:
		preferred = find_child("NewCharacterButton", true, false) as Button
	if preferred != null and not preferred.disabled:
		preferred.grab_focus()
		return
	var buttons := ui_root.find_children("*", "Button", true, false)
	for button: Button in buttons:
		if not button.disabled and button.is_inside_tree():
			button.grab_focus()
			return


func _column(parent: Node, gap: int) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", gap)
	parent.add_child(container)
	return container


func _row(parent: Node, gap: int) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", gap)
	parent.add_child(container)
	return container


func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("141e27ed"), Color("736044"), 20))
	parent.add_child(panel)
	return _column(panel, 12)


func _label(parent: Node, key: String, size: int = 16, color: Color = Color("afbbc2"), serif: bool = false) -> Label:
	var label := Label.new()
	label.text = tr(key) if not key.is_empty() else ""
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if serif:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Georgia", "DejaVu Serif", "Liberation Serif"])
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label


func _wrapped(parent: Node, key: String, size: int, width: float, color: Color = Color("afbbc2")) -> Label:
	var label := _label(parent, key, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	return label


func _button(parent: Node, key: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = tr(key) if not key.is_empty() else ""
	button.custom_minimum_size.y = 40
	if primary:
		button.add_theme_stylebox_override("normal", _style(Color("c5a56a"), Color("ead5a4"), 12))
		button.add_theme_stylebox_override("hover", _style(Color("ddbe83"), Color("f6e0ac"), 12))
		button.add_theme_stylebox_override("pressed", _style(Color("ac8950"), Color("ead5a4"), 12))
		button.add_theme_color_override("font_color", Color("1c2429"))
		button.add_theme_color_override("font_hover_color", Color("1c2429"))
		button.add_theme_color_override("font_pressed_color", Color("1c2429"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style(background: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding * 0.65
	style.content_margin_bottom = padding * 0.65
	return style


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	for type in ["Button", "OptionButton", "LineEdit", "Label"]:
		result.set_color("font_color", type, Color("e4dece"))
	for type in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, _style(Color("233039"), Color("59615e"), 12))
		result.set_stylebox("hover", type, _style(Color("34424a"), Color("c5a56a"), 12))
		result.set_stylebox("pressed", type, _style(Color("1d282f"), Color("d6ba7c"), 12))
		result.set_stylebox("disabled", type, _style(Color("1b252d"), Color("384348"), 12))
		var focus := _style(Color.TRANSPARENT, Color("f3dba2"), 0)
		focus.set_border_width_all(2)
		result.set_stylebox("focus", type, focus)
		result.set_color("font_disabled_color", type, Color("69757b"))
	result.set_stylebox("normal", "LineEdit", _style(Color("101a22"), Color("63716f"), 12))
	result.set_stylebox("focus", "LineEdit", _style(Color.TRANSPARENT, Color("d7bd82"), 12))
	result.set_color("font_placeholder_color", "LineEdit", Color("869397"))
	result.set_stylebox("panel", "PopupMenu", _style(Color("17232c"), Color("736044"), 12))
	result.set_stylebox("panel", "AcceptDialog", _style(Color("17232c"), Color("736044"), 20))
	return result
