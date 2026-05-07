# Content Engine Regression Report

- Overall: PASS
- Step count: 28
- Required PASS: 24/24
- Failed required steps: 0

## Phase Summary

- compile: 1/1 PASS
- guarded_write: 1/2 PASS
- hygiene: 4/4 PASS
- manifest: 2/2 PASS
- negative_fixture: 3/3 PASS
- preflight: 2/2 PASS
- preview: 7/10 PASS
- probe: 2/2 PASS
- scaffold: 2/2 PASS

## Failed Steps

- 3 runtime_export_dry_run_validator (required=false) exit=1
- 7 runtime_export_diff_report_validator (required=false) exit=1
- 9 runtime_exporter_preview_validator (required=false) exit=1
- 13 runtime_exporter_guarded_write_validator (required=false) exit=1

## Runtime Safety Summary

- preview_formal_runtime_sha_unchanged: true
- preview_runtime_dir_allowed_only: true
- runtime_dir_allowed_only_end: true

## Manifest/Checksum Summary

- runtime_export_manifest_validator_pass: true

## Loader/Probe Summary

- runtime_loader_godot_probe_validator_pass: true
- runtime_loader_scaffold_validator_pass: true

## Negative Fixture Summary

- runtime_loader_negative_fixture_validator_pass: true
- negative_fixture_match_all_matched: true
- negative_fixture_returned_domain_count_zero: true
- negative_fixture_write_api_present_false: true

## Godot Warning Summary

- warning_detected: true
- Godot warning is tracked as independent hygiene issue and does not block content engine regression when exit code is 0.

## High-Risk Files

- scripts/card_data.gd unchanged
- scripts/battle_state_machine.gd unchanged
- scripts/combat_resolver.gd unchanged
- scenes/*.tscn unchanged
- data/story_battles/*.tsv unchanged
