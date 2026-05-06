extends RefCounted

func ending_data_for_flag(flag: String) -> Dictionary:
	match flag:
		"true_resolution":
			return {
				"id": "true_resolution",
				"title": "结局：海门真收束",
				"status": "海门真收束",
				"text": "堂上开卷。\n\n海门起风。\n\n这一次，军令、人声、旧案都没有退。",
				"feedback": "军功让你进堂，旧案让你说话，清望让别人敢信。"
			}
		"court_exposure":
			return {
				"id": "court_exposure",
				"title": "结局：堂审翻案",
				"status": "堂审翻案",
				"text": "案卷被迫摊开。\n\n堂外很静。\n\n你赢了一场堂审，却还要等人敢抬头。\n\n然而这就是事情的真相吗？",
				"feedback": "军功和旧案足以开卷，但清望不足时，真相仍显得孤。"
			}
		"reputation_redress":
			return {
				"id": "reputation_redress",
				"title": "结局：清望昭雪",
				"status": "清望昭雪",
				"text": "堂上无人开口。\n\n堂外，有人替你跪了一地。\n\n案卷终于不能只在灯下合上。\n\n然而这就是事情的真相吗？",
				"feedback": "清望让别人敢信你，旧案因此有了见光的缝。"
			}
		"military_reputation":
			return {
				"id": "military_reputation",
				"title": "结局：封海得众",
				"status": "封海得众",
				"text": "海口封住了。\n\n百姓没有散。\n\n你第一次觉得军令也能护住活人。\n\n然而这就是你想要的吗？",
				"feedback": "军功给你权力，清望让权力没有只剩冷铁。"
			}
		"private_truth":
			return {
				"id": "private_truth",
				"title": "结局：私查真相",
				"status": "私查真相",
				"text": "箭从岸上来。\n\n这一次，没有人替他灭口。\n\n师父站得很远。\n\n然而这就是事情的真相吗？",
				"feedback": "旧案让你说得出话，但没有足够军功时，真相仍难进堂。"
			}
		"military_promotion":
			return {
				"id": "military_promotion",
				"title": "结局：军功升迁",
				"status": "军功升迁",
				"text": "你升入卫中。\n\n旧案也封在卫中。\n\n潮声隔着官印，仍然很近。\n\n然而这就是你想要的吗？",
				"feedback": "军功让你进得了堂，也让堂门在你身后落锁。"
			}
		"isolated_evidence":
			return {
				"id": "isolated_evidence",
				"title": "结局：孤证难鸣",
				"status": "孤证难鸣",
				"text": "你知道箭从哪里来。\n\n纸也知道。\n\n可是堂上没有人接这句话。\n\n然而这就是事情的真相吗？",
				"feedback": "旧案足够深，但军功和清望都不足时，真相只能先活在你手里。"
			}
		"martial_survival":
			return {
				"id": "martial_survival",
				"title": "结局：武境破围",
				"status": "武境破围",
				"text": "你杀出海门。\n\n身后火起，堂上灯灭。\n\n旧案没有开卷，但没人再敢轻易灭你的口。\n\n然而这就是你想要的吗？",
				"feedback": "武境能让你活下来，却不能替你赢得堂口和人心。"
			}
		"surface_pirate":
			return {
				"id": "surface_pirate",
				"title": "结局：表层平倭",
				"status": "表层平倭",
				"text": "倭患平了。\n\n案卷仍少一页。\n\n师父没有看你。\n\n然而这就是你想要的吗？",
				"feedback": "表面的海寇被清掉了，旧案还在潮下。"
			}
	return {}

func ending_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for flag in [
		"true_resolution",
		"court_exposure",
		"reputation_redress",
		"military_reputation",
		"military_promotion",
		"private_truth",
		"isolated_evidence",
		"martial_survival",
		"surface_pirate",
	]:
		var ending := ending_data_for_flag(flag)
		if not ending.is_empty():
			catalog.append(ending)
	return catalog
