extends Node
## Changes become visible in memory only after a successful disk transaction.

signal changed

const MAX_CHARACTERS: int = 8
const SAVE_VERSION: int = 1

var storage_path: String = "user://characters.json"
var characters: Array[Dictionary] = []
var selected_character_id: String = ""
var error_key: String = ""
var can_write: bool = true
var return_to_roster: bool = false


func _ready() -> void:
	if SaveMigration.failed:
		_load_failed()
	else:
		load_characters()


func load_characters() -> bool:
	characters.clear()
	selected_character_id = ""
	error_key = ""
	can_write = true
	# Never silently replace an unreadable or incompatible save with an empty one.
	if not FileAccess.file_exists(storage_path):
		if FileAccess.file_exists(storage_path + ".bak"):
			return _load_failed()
		changed.emit()
		return true
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return _load_failed()
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _load_failed()
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != SAVE_VERSION:
		return _load_failed()
	if not data.get("characters") is Array or not data.get("selected_character_id") is String:
		return _load_failed()
	if data.characters.size() > MAX_CHARACTERS:
		return _load_failed()
	var loaded: Array[Dictionary] = []
	var ids: Array[String] = []
	var names: Array[String] = []
	for entry: Variant in data.characters:
		if not entry is Dictionary:
			return _load_failed()
		if not entry.get("id") is String or not entry.get("name") is String or not entry.get("class_id") is String:
			return _load_failed()
		if entry.id.is_empty() or entry.id in ids or entry.name.to_lower() in names:
			return _load_failed()
		if not validate_name(entry.name).is_empty() or entry.name != entry.name.strip_edges():
			return _load_failed()
		if CharacterClasses.find_class(entry.class_id) == null:
			return _load_failed()
		ids.append(entry.id)
		names.append(entry.name.to_lower())
		loaded.append({"id": entry.id, "name": entry.name, "class_id": entry.class_id})
	characters = loaded
	selected_character_id = data.selected_character_id
	if not selected_character_id in ids:
		selected_character_id = "" if characters.is_empty() else str(characters[0].id)
	changed.emit()
	return true


func _load_failed() -> bool:
	can_write = false
	error_key = "ERROR_LOAD"
	changed.emit()
	return false


func selected_character() -> Dictionary:
	for character in characters:
		if character.id == selected_character_id:
			return character.duplicate()
	return {}


func validate_name(character_name: String) -> String:
	# Check controls before trimming so tabs/newlines cannot disguise a valid name.
	for index in range(character_name.length()):
		var code := character_name.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159):
			return "ERROR_NAME_CONTROL"
	var trimmed := character_name.strip_edges()
	if trimmed.length() < 2 or trimmed.length() > 20:
		return "ERROR_NAME_LENGTH"
	return ""


func validate_creation(character_name: String, class_id: String) -> String:
	if not can_write:
		return "ERROR_LOAD"
	if characters.size() >= MAX_CHARACTERS:
		return "ERROR_ROSTER_FULL"
	var name_error := validate_name(character_name)
	if not name_error.is_empty():
		return name_error
	for character in characters:
		if character.name.to_lower() == character_name.strip_edges().to_lower():
			return "ERROR_NAME_DUPLICATE"
	if CharacterClasses.find_class(class_id) == null:
		return "ERROR_CLASS_REQUIRED"
	return ""


func create_character(character_name: String, class_id: String) -> bool:
	error_key = validate_creation(character_name, class_id)
	if not error_key.is_empty():
		return false
	var next := characters.duplicate(true)
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	next.append({"id": id, "name": character_name.strip_edges(), "class_id": class_id})
	return _commit(next, id)


func select_character(id: String) -> bool:
	for character in characters:
		if character.id == id:
			return _commit(characters, id)
	error_key = "ERROR_CHARACTER_MISSING"
	return false


func delete_character(id: String) -> bool:
	var next: Array[Dictionary] = []
	var deleted_index := -1
	for index in range(characters.size()):
		if characters[index].id == id:
			deleted_index = index
		else:
			next.append(characters[index].duplicate())
	if deleted_index < 0:
		error_key = "ERROR_CHARACTER_MISSING"
		return false
	var selection := selected_character_id
	if selection == id:
		selection = "" if next.is_empty() else str(next[mini(deleted_index, next.size() - 1)].id)
	return _commit(next, selection)


func _commit(next: Array[Dictionary], selection: String) -> bool:
	if not can_write:
		error_key = "ERROR_LOAD"
		return false
	var temporary := storage_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _save_failed()
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "selected_character_id": selection, "characters": next}, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _save_failed()
	if FileAccess.file_exists(storage_path):
		if DirAccess.copy_absolute(storage_path, storage_path + ".bak") != OK:
			DirAccess.remove_absolute(temporary)
			return _save_failed()
	if DirAccess.rename_absolute(temporary, storage_path) != OK:
		DirAccess.remove_absolute(temporary)
		return _save_failed()
	characters.assign(next.duplicate(true))
	selected_character_id = selection
	error_key = ""
	changed.emit()
	return true


func _save_failed() -> bool:
	error_key = "ERROR_SAVE"
	return false
