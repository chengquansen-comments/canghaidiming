extends RefCounted

static func has_query_flag(name: String) -> bool:
	var value := query_param(name).to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"


static func query_param(name: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var raw_query := _location_search()
	if raw_query == "":
		return ""
	var query := raw_query.substr(1) if raw_query.begins_with("?") else raw_query
	for part in query.split("&", false):
		if part == "":
			continue
		var key := part
		var value := ""
		var separator := part.find("=")
		if separator >= 0:
			key = part.substr(0, separator)
			value = part.substr(separator + 1)
		if key.uri_decode() == name:
			return value.uri_decode()
	return ""


static func set_body_dataset(name: String, value: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(
		"document.body.dataset[%s] = %s;" % [_js_string(name), _js_string(value)],
		true
	)


static func _location_search() -> String:
	var result: Variant = JavaScriptBridge.eval("window.location.search || '';", true)
	return "" if result == null else String(result)


static func _js_string(value: String) -> String:
	return "\"%s\"" % value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
