extends Node
## Language preference is separate from character data.

const SUPPORTED: Array[String] = ["en", "es"]
var storage_path: String = "user://settings.cfg"


func _ready() -> void:
	var settings := ConfigFile.new()
	var locale := "en"
	if settings.load(storage_path) == OK:
		var stored: Variant = settings.get_value("interface", "language", "en")
		if stored is String and stored in SUPPORTED:
			locale = stored
	TranslationServer.set_locale(locale)


func set_language(locale: String) -> bool:
	if not locale in SUPPORTED:
		return false
	var settings := ConfigFile.new()
	settings.set_value("interface", "language", locale)
	if settings.save(storage_path) != OK:
		return false
	TranslationServer.set_locale(locale)
	return true


func make_selector() -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "LanguageSelector"
	selector.add_item(tr("LANGUAGE_ENGLISH"))
	selector.add_item(tr("LANGUAGE_SPANISH"))
	selector.select(1 if TranslationServer.get_locale().begins_with("es") else 0)
	selector.tooltip_text = tr("LANGUAGE")
	selector.item_selected.connect(func(index: int) -> void:
		if not set_language(SUPPORTED[index]):
			selector.select(1 if TranslationServer.get_locale().begins_with("es") else 0)
			var dialog := AcceptDialog.new()
			dialog.title = tr("ERROR_TITLE")
			dialog.dialog_text = tr("ERROR_LANGUAGE_SAVE")
			dialog.ok_button_text = tr("OK")
			selector.add_child(dialog)
			dialog.popup_centered(Vector2i(420, 160))
			dialog.confirmed.connect(dialog.queue_free)
	)
	return selector
