# Runtime Loader Preflight Report

- Stage: v0.8d loader preflight (analysis only)
- Records: 2
- loader_ready=true: 2
- blocked: 0

## Preflight Rows

| Runtime Domain | Artifact ID | Manifest Status | JSON Parse | Checksum | Schema FP | Content FP | Read Mode | Failure Mode | Loader Ready | Blocked Reason |
|---|---|---|---|---|---|---|---|---|---|---|
| battle_reward | generated_battle_reward_plan | registered | ok | matched | matched | matched | manifest_first | fail_closed | true |  |
| card_pool | generated_card_pool | registered | ok | matched | matched | matched | manifest_first | fail_closed | true |  |

## Scope Boundary

- v0.8d is preflight only and does not implement any Godot loader.
- proposed_godot_touchpoints are future_touchpoint_only suggestions.
- No .gd runtime files are created or modified in this stage.
