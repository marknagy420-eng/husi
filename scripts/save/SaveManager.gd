extends Node

const SAVE_PATH := "user://save.json"

# Autoloaded persistence service. Gameplay scripts pass plain dictionaries here.
var default_data := {
	"currency": 25,
	"pet_stats": {
		"hunger": 70,
		"happiness": 70,
		"energy": 72
	},
	"owned_items": ["default"],
	"selected_skin": "default",
	"owned_backgrounds": ["default"],
	"selected_background": "default"
}

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return default_data.duplicate(true)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file. Starting with defaults.")
		return default_data.duplicate(true)

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Save file is invalid JSON. Starting with defaults.")
		return default_data.duplicate(true)

	return _merge_with_defaults(parsed)

func save_game(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file.")
		return

	file.store_string(JSON.stringify(_merge_with_defaults(data), "\t"))

func _merge_with_defaults(data: Dictionary) -> Dictionary:
	var merged := default_data.duplicate(true)
	for key in data.keys():
		if key == "pet_stats" and data[key] is Dictionary:
			for stat_key in data[key].keys():
				merged["pet_stats"][stat_key] = data[key][stat_key]
		else:
			merged[key] = data[key]
	return merged
