extends SceneTree

func _initialize() -> void:
	var preview_manifest_path := "res://data/runtime_preview/content_engine/battle_rewards.preview_manifest.json"
	var preview_json_path := "res://data/runtime_preview/content_engine/battle_rewards.preview.json"
	var manifest_text := ""
	var preview_text := ""
	if FileAccess.file_exists(preview_manifest_path):
		manifest_text = FileAccess.get_file_as_string(preview_manifest_path)
	if FileAccess.file_exists(preview_json_path):
		preview_text = FileAccess.get_file_as_string(preview_json_path)
	var manifest := JSON.parse_string(manifest_text)
	var preview := JSON.parse_string(preview_text)
	var runtime_ready := false
	var selected_reward_policy := ""
	var reward_count := 0
	if manifest is Dictionary:
		runtime_ready = bool(manifest.get("runtime_ready", false))
		selected_reward_policy = str(manifest.get("selected_reward_policy", ""))
	if preview is Dictionary:
		reward_count = int((preview.get("rewards", []) as Array).size())
	print("REWARD_PREVIEW_READONLY_PROBE_JSON_BEGIN")
	print(JSON.stringify({
		"runtime_ready": runtime_ready,
		"selected_reward_policy": selected_reward_policy,
		"preview_reward_count": reward_count,
		"readonly_probe": true,
	}))
	print("REWARD_PREVIEW_READONLY_PROBE_JSON_END")
	quit()
