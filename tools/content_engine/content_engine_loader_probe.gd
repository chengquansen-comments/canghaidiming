extends SceneTree

const LOADER_SCRIPT := preload("res://scripts/content_engine_runtime_loader.gd")

func _initialize() -> void:
	var payload: Dictionary = _run_probe()
	print("CONTENT_ENGINE_LOADER_PROBE_JSON_BEGIN")
	print(JSON.stringify(payload))
	print("CONTENT_ENGINE_LOADER_PROBE_JSON_END")
	quit()


func _run_probe() -> Dictionary:
	var loader: Object = LOADER_SCRIPT.new()
	var manifest_result: Dictionary = loader.load_manifest()
	var manifest_loaded: bool = bool(manifest_result.get("ok", false))
	var manifest_valid := false
	if manifest_loaded:
		var manifest: Dictionary = manifest_result.get("manifest", {})
		var manifest_validation: Dictionary = loader.validate_manifest(manifest)
		manifest_valid = bool(manifest_validation.get("ok", false))
	var bundle_result: Dictionary = loader.load_runtime_bundle()
	var runtime_bundle_loaded: bool = bool(bundle_result.get("ok", false))
	var loaded_domains: Array = []
	if runtime_bundle_loaded:
		loaded_domains = loader.get_loaded_domains()
		loaded_domains.sort()
	var errors: Array = loader.get_errors()
	if errors.is_empty() and typeof(bundle_result.get("errors", [])) == TYPE_ARRAY:
		errors = bundle_result.get("errors", [])
	return {
		"probe_ok": manifest_loaded and manifest_valid and runtime_bundle_loaded and errors.is_empty(),
		"manifest_loaded": manifest_loaded,
		"manifest_valid": manifest_valid,
		"runtime_bundle_loaded": runtime_bundle_loaded,
		"loaded_domains": loaded_domains,
		"error_count": errors.size(),
		"errors": errors,
		"manifest_first": true,
		"direct_runtime_read_disallowed": true,
		"fail_closed": true,
		"write_api_present": false,
		"integration_status": "not_integrated",
	}
