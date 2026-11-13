extends Node
## Preserve local data when moving from the prototype's former application name.

var failed: bool = false


func _ready() -> void:
	var current := OS.get_user_data_dir()
	failed = not migrate(current.get_base_dir().path_join("WAW"), current)


func migrate(source: String, destination: String) -> bool:
	if source == destination:
		return true
	if not DirAccess.dir_exists_absolute(destination):
		return false
	var files: Array[String] = ["settings.cfg"]
	if not FileAccess.file_exists(destination.path_join("characters.json")) and not FileAccess.file_exists(destination.path_join("characters.json.bak")):
		files.append_array(["characters.json", "characters.json.bak"])
	for filename in files:
		var old_file := source.path_join(filename)
		var new_file := destination.path_join(filename)
		if FileAccess.file_exists(old_file) and not FileAccess.file_exists(new_file):
			if DirAccess.copy_absolute(old_file, new_file) != OK:
				return false
	return true
