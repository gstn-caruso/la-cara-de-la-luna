extends SceneTree

var failures := 0
var store: Node
var test_path := "user://store_test_%s.json" % Time.get_ticks_usec()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	store = load("res://scripts/character_store.gd").new()
	store.storage_path = test_path
	_check(store.load_characters() and store.characters.is_empty(), "First launch starts empty")
	_check(not store.create_character("A", "warrior"), "Short names are rejected")
	_check(not store.create_character("a".repeat(21), "warrior"), "Long names are rejected")
	_check(not store.create_character("Hero\n", "warrior"), "Control characters are rejected before trimming")
	_check(not store.create_character("Hero", "unknown"), "Unknown classes are rejected")
	_check(store.create_character("  Éowyn  ", "warrior"), "Unicode names and outer whitespace are supported")
	_check(store.selected_character().name == "Éowyn", "Names are trimmed on save")
	_check(not store.create_character("éOWYN", "mage"), "Duplicate names ignore case")
	var warrior_id: String = store.selected_character_id
	var first_save := FileAccess.get_file_as_string(test_path)
	_check(store.create_character("Shadow", "rogue"), "A rogue can be created")
	_check(FileAccess.get_file_as_string(test_path + ".bak") == first_save, "The previous valid save is backed up")
	var rogue_id: String = store.selected_character_id
	_check(store.create_character("Ember", "mage"), "A mage can be created")
	var mage_id: String = store.selected_character_id
	_check(store.select_character(rogue_id), "Selection saves successfully")
	var reloaded: Node = load("res://scripts/character_store.gd").new()
	reloaded.storage_path = test_path
	_check(reloaded.load_characters(), "A fresh store loads the saved roster")
	_check(reloaded.characters.size() == 3 and reloaded.selected_character_id == rogue_id, "The roster and selection survive restart")
	_check(store.delete_character(rogue_id), "Deletion commits successfully")
	_check(store.selected_character_id == mage_id, "Deleting the selection selects the next character")
	_check(store.select_character(warrior_id), "An earlier character remains selectable")
	for index in range(6):
		_check(store.create_character("Adventurer %d" % index, "mage"), "Slots can be filled")
	_check(store.characters.size() == 8, "The roster holds eight characters")
	_check(not store.create_character("Overflow", "rogue"), "A ninth character is rejected")

	# An unavailable destination must leave both the in-memory roster and disk intact.
	var snapshot: Array = store.characters.duplicate(true)
	var selected: String = store.selected_character_id
	var saved := FileAccess.get_file_as_string(test_path)
	store.storage_path = "user://missing_%s/characters.json" % Time.get_ticks_usec()
	_check(not store.delete_character(selected), "Failed writes report failure")
	_check(store.characters == snapshot and store.selected_character_id == selected, "Failed writes do not mutate memory")
	_check(FileAccess.get_file_as_string(test_path) == saved, "Failed writes preserve the existing save")
	store.storage_path = test_path

	for invalid in ["broken JSON", '{"version":2,"characters":[],"selected_character_id":""}', '{"version":1,"characters":[{}],"selected_character_id":""}']:
		var file := FileAccess.open(test_path, FileAccess.WRITE)
		file.store_string(invalid)
		file.close()
		_check(not store.load_characters() and not store.can_write, "Invalid or unsupported saves lock writes")
		_check(not store.create_character("Replacement", "warrior"), "A bad save cannot be replaced by creation")
		_check(FileAccess.get_file_as_string(test_path) == invalid, "Invalid source files remain untouched")
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string(saved)
	file.close()
	_check(store.load_characters() and store.can_write, "Retry succeeds after restoring valid data")
	while not store.characters.is_empty():
		store.delete_character(store.characters[0].id)
	_check(store.selected_character().is_empty() and store.selected_character_id == "", "Deleting the final character clears selection")
	store.free()
	reloaded.free()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(test_path + suffix)
	if failures == 0:
		print("PASS: character persistence, validation, capacity, selection, deletion and save protection.")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
