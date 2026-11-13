extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var base := "user://migration_test_%s" % Time.get_ticks_usec()
	var source := base.path_join("old")
	var destination := base.path_join("new")
	DirAccess.make_dir_recursive_absolute(source)
	DirAccess.make_dir_recursive_absolute(destination)
	_write(source.path_join("characters.json"), "old characters")
	_write(source.path_join("characters.json.bak"), "old backup")
	_write(source.path_join("settings.cfg"), "old language")
	var migration: Node = load("res://scripts/save_migration.gd").new()
	var passed: bool = migration.migrate(source, destination)
	passed = passed and FileAccess.get_file_as_string(destination.path_join("characters.json")) == "old characters"
	passed = passed and FileAccess.get_file_as_string(source.path_join("characters.json")) == "old characters"
	_write(destination.path_join("characters.json"), "new characters")
	_write(destination.path_join("settings.cfg"), "new language")
	passed = passed and migration.migrate(source, destination)
	passed = passed and FileAccess.get_file_as_string(destination.path_join("characters.json")) == "new characters"
	passed = passed and FileAccess.get_file_as_string(destination.path_join("settings.cfg")) == "new language"
	passed = passed and not migration.migrate(source, base.path_join("missing"))
	for folder in [source, destination]:
		for filename in ["characters.json", "characters.json.bak", "settings.cfg"]:
			DirAccess.remove_absolute(folder.path_join(filename))
		DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute(base)
	migration.free()
	if passed:
		print("PASS: renamed application migrates legacy saves without overwriting data.")
	else:
		push_error("Save migration failed")
	quit(0 if passed else 1)


func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()
