extends Node3D
## Combat sandbox: approach a skeleton to exchange automatic basic melee attacks.

@onready var player: CharacterBody3D = $Player
@onready var state_label: Label = $Overlay/Layout/Content/Footer/State
var combat_panel: VBoxContainer
var health_bar: ProgressBar
var target_label: Label
var attack_label: Label
var message_label: Label
var message_time: float = 0.0


func _ready() -> void:
	var language_selector := Localization.make_selector()
	$Overlay/Layout/Content/Header.add_child(language_selector)
	_update_identity()
	if player.definition != null:
		var enemy := BasicSkeleton.new()
		enemy.name = "BasicSkeleton"
		enemy.position = Vector3(0, 0, -4.5)
		add_child(enemy)
		_build_combat_hud()
		player.respawned.connect(_on_player_respawned)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_identity()
		var header := $Overlay/Layout/Content/Header
		var previous := header.get_node_or_null("LanguageSelector")
		if previous != null:
			header.remove_child(previous)
			previous.queue_free()
		header.add_child(Localization.make_selector())


func _update_identity() -> void:
	var character := CharacterStore.selected_character()
	if not character.is_empty():
		var title: Label = $Overlay/Layout/Content/Title
		title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		title.text = character.name
		var subtitle: Label = $Overlay/Layout/Content/Subtitle
		subtitle.text = tr("WORLD_CHARACTER") % [character.name, tr(CharacterClasses.find_class(character.class_id).name_key)]
		subtitle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _input(event: InputEvent) -> void:
	if player.definition != null and event.is_action_pressed("select_enemy") and not event.is_echo():
		player.select_target(_nearest_enemy())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		CharacterStore.return_to_roster = true
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred("res://scenes/frontend.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if player.definition == null or event.is_echo():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var camera: Camera3D = $Camera3D
		var origin := camera.project_ray_origin(event.position)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * 150.0, 2)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider") is BasicSkeleton:
			player.select_target(hit.collider)
		else:
			player.select_target(null)
		get_viewport().set_input_as_handled()


func _nearest_enemy() -> BasicSkeleton:
	var nearest: BasicSkeleton
	var distance: float = 12.0
	for enemy: BasicSkeleton in get_tree().get_nodes_in_group("basic_skeletons"):
		var candidate := player.global_position.distance_to(enemy.global_position)
		if not enemy.dead and candidate < distance:
			nearest = enemy
			distance = candidate
	return nearest


func _process(delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	state_label.text = tr("WORLD_WALKING") % speed if speed > 0.05 else tr("WORLD_IDLE")
	if combat_panel == null:
		return
	health_bar.value = player.health
	health_bar.get_node("Text").text = tr("COMBAT_HEALTH") % [player.health, player.MAX_HEALTH]
	if is_instance_valid(player.target) and not player.target.dead:
		target_label.text = tr("COMBAT_TARGET") % [tr("ENEMY_SKELETON"), player.target.health, player.target.MAX_HEALTH]
		if player.auto_attacking:
			attack_label.text = tr("COMBAT_ATTACKING") if player._in_attack_range(player.target) else tr("COMBAT_OUT_OF_RANGE")
		else:
			attack_label.text = tr("COMBAT_PAUSED")
	else:
		target_label.text = tr("COMBAT_NO_TARGET")
		attack_label.text = tr("COMBAT_SELECT_HINT")
	message_time = maxf(0.0, message_time - delta)
	message_label.text = tr("COMBAT_RESPAWNED") if message_time > 0.0 else tr("COMBAT_WEAPON_" + player.definition.basic_weapon.to_upper())


func _build_combat_hud() -> void:
	var panel := PanelContainer.new()
	panel.name = "CombatHUD"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = 340
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.93, 0.89, 0.94)
	style.set_content_margin_all(14)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	$Overlay/Layout/Content/Space.add_child(panel)
	combat_panel = VBoxContainer.new()
	combat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_panel.add_theme_constant_override("separation", 12)
	panel.add_child(combat_panel)
	health_bar = ProgressBar.new()
	health_bar.name = "PlayerHealth"
	health_bar.custom_minimum_size.y = 26
	health_bar.max_value = player.MAX_HEALTH
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("453a37")
	health_background.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("background", health_background)
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("46705b")
	health_fill.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	combat_panel.add_child(health_bar)
	var health_text := Label.new()
	health_text.name = "Text"
	health_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_text.add_theme_color_override("font_color", Color.WHITE)
	health_bar.add_child(health_text)
	target_label = _combat_label("Target")
	attack_label = _combat_label("AttackState")
	message_label = _combat_label("CombatMessage")
	message_label.add_theme_font_size_override("font_size", 13)


func _combat_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_panel.add_child(label)
	return label


func _on_player_respawned() -> void:
	message_time = 4.0
