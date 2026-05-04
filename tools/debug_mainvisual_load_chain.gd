extends SceneTree

# MainVisual inheritance-chain loader diagnostic.
#
# Usage:
#   HOME=/private/tmp godot --headless --path . --script tools/debug_mainvisual_load_chain.gd
#
# Purpose:
#   Godot often reports the outer child script when any ancestor in the extends
#   chain fails to parse. This script reads the real extends chain from the
#   current files, prints it, then loads the chain from deepest ancestor upward.
#   The first LOAD_FAILED entry is the file to inspect; Godot should also print
#   the real parser error above it.

const ENTRY_SCRIPT := "res://scripts/battle_controller_visual_story_return_intent_visibility.gd"
const ENTRY_SCENE := "res://scenes/MainVisual.tscn"

func _initialize() -> void:
	print("=== MainVisual load-chain diagnostic start ===")
	var chain: Array[String] = _build_extends_chain(ENTRY_SCRIPT)
	if chain.is_empty():
		printerr("CHAIN_FAILED: could not build extends chain from %s" % ENTRY_SCRIPT)
		quit(1)
		return
	print("=== Extends chain child -> parent ===")
	for i in range(chain.size()):
		print("CHAIN[%02d]: %s" % [i, chain[i]])
	print("=== Load chain parent -> child ===")
	var load_order: Array[String] = chain.duplicate()
	load_order.reverse()
	load_order.append(ENTRY_SCENE)
	for path: String in load_order:
		print("LOAD_BEGIN: %s" % path)
		var resource: Resource = load(path)
		if resource == null:
			printerr("LOAD_FAILED: %s" % path)
			printerr("=== MainVisual load-chain diagnostic failed ===")
			quit(1)
			return
		print("LOAD_OK: %s -> %s" % [path, resource.get_class()])
	print("=== MainVisual load-chain diagnostic passed ===")
	quit(0)

func _build_extends_chain(entry_path: String) -> Array[String]:
	var chain: Array[String] = []
	var seen := {}
	var current_path := entry_path
	while current_path != "":
		if bool(seen.get(current_path, false)):
			printerr("CHAIN_LOOP: %s" % current_path)
			return chain
		seen[current_path] = true
		chain.append(current_path)
		var next_path := _read_extends_path(current_path)
		if next_path == "":
			break
		current_path = next_path
	return chain

func _read_extends_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		printerr("CHAIN_FILE_MISSING: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("CHAIN_FILE_OPEN_FAILED: %s" % path)
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if not line.begins_with("extends"):
			return ""
		return _parse_extends_target(line)
	return ""

func _parse_extends_target(line: String) -> String:
	var first_quote := line.find("\"")
	if first_quote < 0:
		return ""
	var second_quote := line.find("\"", first_quote + 1)
	if second_quote < 0:
		return ""
	return line.substr(first_quote + 1, second_quote - first_quote - 1)
