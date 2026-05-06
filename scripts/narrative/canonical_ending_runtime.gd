extends RefCounted

# Pure ending selection/catalog helper for canonical narrative controllers.
#
# It does not render UI, save context, advance nodes, switch scenes, start
# battles, or call owner/controller methods.

const FLAG_TRUTH_REPORT := "truth_report"
const FLAG_PRIVATE_INVESTIGATION := "private_investigation"
const FLAG_MERIT_COVER := "merit_cover"
const FLAG_SILENCE := "silence"


static func ending_data(selected_flag: String, military_merit: int, clean_reputation: int, case_clues: int) -> Dictionary:
	var flagged := ending_data_for_flag(selected_flag)
	if not flagged.is_empty():
		return flagged
	if case_clues >= 4:
		return {
			"id": FLAG_PRIVATE_INVESTIGATION,
			"title": "结局：旧案浮起",
			"status": "旧案浮起",
			"text": "你藏下一份证据。\n\n纸很薄。\n\n却压得甲很沉。\n\n师父说：不要再问。\n\n你第一次没有听。",
			"feedback": "你接近了真相，但军门与师父都开始变得沉默。",
		}
	if military_merit >= 4 and case_clues < 4:
		return {
			"id": FLAG_MERIT_COVER,
			"title": "结局：军功入册",
			"status": "军功入册",
			"text": "捷报写得很好。\n\n首级数得很准。\n\n案卷少了一页。\n\n你升了一级。",
			"feedback": "你立下了功名，但旧案从案卷里退后了一步。",
		}
	if clean_reputation >= 4 and case_clues < 4:
		return {
			"id": FLAG_TRUTH_REPORT,
			"title": "结局：清名在外",
			"status": "清名在外",
			"text": "百姓记得你救过人。\n\n军门记得你误过令。\n\n师父说：好名声也会杀人。\n\n潮声没有回答。",
			"feedback": "你保住了道义，却还没有把真相从潮声里拉出来。",
		}
	return ending_data_for_flag(FLAG_SILENCE)


static func ending_data_for_flag(flag: String) -> Dictionary:
	match flag:
		FLAG_TRUTH_REPORT:
			return {
				"id": FLAG_TRUTH_REPORT,
				"title": "结局：据实上报",
				"status": "据实上报",
				"text": "你把话说完。\n\n屋里安静了很久。\n\n案卷没有立刻合上。\n\n潮声从门外涌进来。",
				"feedback": "你选择把真相放到军门案上，清望与旧案线索会成为你的支撑。",
			}
		FLAG_PRIVATE_INVESTIGATION:
			return {
				"id": FLAG_PRIVATE_INVESTIGATION,
				"title": "结局：藏证私查",
				"status": "藏证私查",
				"text": "袖中有纸。\n\n心里有潮。\n\n你退下时没有回头。\n\n旧案从此不只在案卷里。",
				"feedback": "你留下了继续追查的火种，但军门与师父都会更沉默。",
			}
		FLAG_MERIT_COVER:
			return {
				"id": FLAG_MERIT_COVER,
				"title": "结局：借功压案",
				"status": "借功压案",
				"text": "你把首级摆出来。\n\n没人再问箱子。\n\n捷报写得顺。\n\n顺得不像真的。",
				"feedback": "你用军功换来当下的通行，但旧案被压回潮声下面。",
			}
		FLAG_SILENCE:
			return {
				"id": FLAG_SILENCE,
				"title": "结局：沉默退下",
				"status": "沉默退下",
				"text": "门关上。\n\n灯还亮着。\n\n师父还站在外面。\n\n你什么都没有说。",
				"feedback": "你没有站上任何一边，悬念被保留下来。",
			}
	return {}


static func ending_flag_from_choice(choice: Dictionary) -> String:
	var flag := str(choice.get("ending_flag", "")).strip_edges()
	var effects = choice.get("effects", {})
	if flag.is_empty() and effects is Dictionary:
		flag = str((effects as Dictionary).get("ending_flag", "")).strip_edges()
	return flag


static func ending_catalog(final_node: Dictionary) -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	var choices = final_node.get("choices", [])
	if not (choices is Array):
		return catalog
	for choice_variant in choices:
		if not (choice_variant is Dictionary):
			continue
		var choice := choice_variant as Dictionary
		var flag := ending_flag_from_choice(choice)
		if flag.is_empty():
			continue
		var ending := ending_data_for_flag(flag)
		if ending.is_empty():
			ending = {
				"id": flag,
				"title": "结局：%s" % str(choice.get("label", choice.get("text", flag))),
				"status": str(choice.get("label", choice.get("text", flag))),
				"text": "尚未整理该结局文本。",
				"feedback": "该结局已经在选择中注册，但缺少正式文本。",
			}
		catalog.append(ending)
	return catalog
