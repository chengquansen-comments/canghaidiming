# AIGC Battle 外部内容总览

- 当前 active profile: `posture_opening_pressure_v0_1`
- 当前 active content pack: `posture_opening_pressure_v0_1_formal_sequence_pack_001`
- 当前 manifest: `data/aigc_battle/generated/posture_opening_pressure_v0_1/runtime_manifest.json`
- profile 数量: `4`
- content pack 数量: `7`

| Active | Profile | Pack | Mode | Encounters | Cards | Decks | Rewards | Export | Balance | Runtime Export | Primitive | Detail |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- |
|  | `posture_basic_v0_1` | `posture_basic_v0_1_formal_sequence_pack_001` | `profile_root` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `-` | ready |
|  | `posture_llm_candidate_v0_1` | `posture_llm_candidate_v0_1_formal_sequence_pack_001` | `profile_root` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `-` | ready |
| YES | `posture_opening_pressure_v0_1` | `posture_opening_pressure_v0_1_formal_sequence_pack_001` | `profile_root` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `opening_pressure` | ready |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_p1_probe_snapshot_001` | `profile_pack_dir` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `opening_pressure` | ready |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_p1_probe_snapshot_002` | `profile_pack_dir` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `opening_pressure` | ready |
|  | `posture_opening_pressure_v0_1` | `posture_opening_pressure_snapshot_001` | `profile_pack_dir` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `opening_pressure` | ready |
|  | `posture_tuned_v0_1b` | `posture_tuned_v0_1b_formal_sequence_pack_001` | `profile_root` | 15 | 40 | 15 | 15 | PASS | PASS | PASS | `-` | ready |

## 控制台命令

- 列出可切换 pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --list`
- 干跑 root pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --dry-run --profile <profile_id>`
- 干跑指定 pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --dry-run --profile <profile_id> --pack <content_pack_id>`
- 安全切换 root pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --profile <profile_id>`
- 安全切换指定 pack：`python3 tools/aigc_battle/aigc_external_profile_switch.py --profile <profile_id> --pack <content_pack_id>`
- 浏览器点击切换或查看明细前先启动本地 server：`python3 tools/aigc_battle/aigc_dashboard_server.py`
