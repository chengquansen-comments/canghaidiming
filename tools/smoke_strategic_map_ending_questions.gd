extends SceneTree

const TRUE_ENDING := "true_resolution"
const CASE_ENDINGS := {
	"court_exposure": true,
	"reputation_redress": true,
	"private_truth": true,
	"isolated_evidence": true,
}
const NON_CASE_ENDINGS := {
	"military_reputation": true,
	"military_promotion": true,
	"martial_survival": true,
	"surface_pirate": true,
}
const CASE_QUESTION := "然而这就是事情的真相吗？"
const WANT_QUESTION := "然而这就是你想要的吗？"

func _init() -> void:
	var packed := load("res://scenes/NarrativeDemo.tscn")
	if not (packed is PackedScene):
		push_error("NarrativeDemo is not a PackedScene")
		quit(1)
		return
	var scene := (packed as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	if not scene.has_method("_ending_data_for_flag"):
		push_error("NarrativeDemo controller missing _ending_data_for_flag")
		quit(1)
		return
	var true_text := _ending_text(scene, TRUE_ENDING)
	if true_text.contains(CASE_QUESTION) or true_text.contains(WANT_QUESTION):
		push_error("True ending must not include unresolved ending question")
		quit(1)
		return
	for ending_id in CASE_ENDINGS.keys():
		var text := _ending_text(scene, ending_id)
		if not text.contains(CASE_QUESTION) or text.contains(WANT_QUESTION):
			push_error("%s must include only case question" % ending_id)
			quit(1)
			return
	for ending_id in NON_CASE_ENDINGS.keys():
		var text := _ending_text(scene, ending_id)
		if not text.contains(WANT_QUESTION) or text.contains(CASE_QUESTION):
			push_error("%s must include only want question" % ending_id)
			quit(1)
			return
	print("Strategic map ending question smoke: OK")
	quit(0)

func _ending_text(scene: Node, ending_id: String) -> String:
	var data: Dictionary = scene.call("_ending_data_for_flag", ending_id)
	return str(data.get("text", ""))
