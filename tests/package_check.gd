extends SceneTree
## Run as an external script against an exported PCK, not the source directory.
func _initialize() -> void:
	var failures: int = 0
	for path: String in ["res://assets/audio/bank.json", "res://assets/models/catalog.json", "res://assets/CREDITS.md"]:
		if not FileAccess.file_exists(path):
			push_error("PACKAGE_FAIL missing " + path)
			failures += 1
	var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/bank.json"))
	for variants: Array in bank.get("sounds", {}).values():
		for path: String in variants:
			if not ResourceLoader.exists(path):
				push_error("PACKAGE_FAIL missing clip " + path)
				failures += 1
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/catalog.json"))
	for entry: Dictionary in catalog:
		if not ResourceLoader.exists("res://assets/models/%s.glb" % entry.model):
			push_error("PACKAGE_FAIL missing model " + str(entry.model))
			failures += 1
	for path: String in ["res://tools/build_art.py", "res://art-source/station_assets.blend", "res://tests/network_test.gd"]:
		if FileAccess.file_exists(path):
			push_error("PACKAGE_FAIL development file exported " + path)
			failures += 1
	print("PACKAGE_PASS" if failures == 0 else "PACKAGE_FAIL")
	quit(0 if failures == 0 else 1)
