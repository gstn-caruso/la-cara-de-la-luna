extends Node3D
## Minimal on-screen feedback; the one-meter grid is drawn by the floor shader.

@onready var player: CharacterBody3D = $Player
@onready var state_label: Label = $Overlay/Layout/Content/Footer/State


func _ready() -> void:
	var language_selector := Localization.make_selector()
	$Overlay/Layout/Content/Header.add_child(language_selector)
	_update_identity()


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
	if event.is_action_pressed("ui_cancel"):
		CharacterStore.return_to_roster = true
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file.call_deferred("res://scenes/frontend.tscn")


func _process(_delta: float) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	state_label.text = tr("WORLD_WALKING") % speed if speed > 0.05 else tr("WORLD_IDLE")
