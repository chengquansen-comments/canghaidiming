# 《大明之沧海嘀鸣》节点视觉矩阵

> 版本：v0.5
> 对齐分支：`main`
> 更新时间：按《美术规划.pdf》review 后，结合 narrative TSV / node_status / 编译产物重新校准
> 用途：统一剧情源头、MVP 流程、visual_path、战斗背景、叙事道具和后续挂接优先级。

---

## 0. 执行入口

美术文档总入口为：

```text
docs/ART_PIPELINE.md
```

本矩阵只负责“节点级状态”。生产节奏和阶段交付见：

```text
docs/ART_PRODUCTION_ROADMAP.md
```

当前权威文档分工：

| 文档 | 作用 |
|---|---|
| `ART_PIPELINE.md` | 美术文档入口、TSV/JSON/运行资源规则 |
| `ART_DIRECTION_GUIDE.md` | 美术目标、风格边界、色彩、构图、禁止事项 |
| `NODE_VISUAL_MATRIX.md` | 每个 node / battle_id / visual_path / 资源状态 |
| `ART_PRODUCTION_ROADMAP.md` | 阶段计划、P0/P1/P2 交付包、验收路线 |
| `ART_REFERENCE_PROMPTS.md` | 参考图与概念图提示词；不作为运行资源清单 |

---

## 1. 当前文件口径

本矩阵必须同时参考三层文件：

```text
剧情内容源头：
- tables/narrative_mvp_prologue_steps.tsv
- tables/narrative_mvp_nodes.tsv

节点流程 / 实装 / 美术挂接源头：
- tables/narrative_mvp_node_status.tsv

编译产物 / 游戏运行读取：
- data/narrative_mvp_nodes.json
```

优先级规则：

1. 节点是否进入当前 MVP 主流程，以 `tables/narrative_mvp_node_status.tsv` 的 `flow_enabled` 为准。
2. 节点当前挂接的视觉资源，以 `visual_path` 为准。
3. 游戏运行验收，以 `data/narrative_mvp_nodes.json` 是否包含对应节点和选择为准。
4. TSV 中 `reserved` 节点可以规划资源，但不作为当前 P0 主流程资源。
5. 若 TSV 源头节点与 JSON 产物结构不同，以运行产物验收为准，同时回查编译脚本。

---

## 2. 状态标记

| 状态 | 含义 |
|---|---|
| `FLOW_PLAYABLE` | `node_status.tsv` 中 `flow_enabled=true` 且 `implementation_status=playable` |
| `FLOW_RESERVED` | `node_status.tsv` 中 `flow_enabled=false`，当前不进入 MVP 主流程 |
| `RUNTIME_PRESENT` | 当前 `data/narrative_mvp_nodes.json` 中存在运行节点 |
| `RUNTIME_MERGED` | TSV 有独立节点，但 JSON 产物中被合并到其他节点选择里或缺失 |
| `VISUAL_WIRED` | `node_status.tsv` 已有 `visual_path` |
| `VISUAL_REUSED` | 当前 `visual_path` 与相邻节点复用，需后续拆专属资源 |
| `TRACK_WIRED` | 资源已通过 `performance_tracks` 进入剧情演出层 |
| `ASSET_READY_UNWIRED` | 资源已存在，但尚未作为 `visual_path` 或 performance track 挂接 |
| `NEEDS_ASSET` | 资源缺失，需要新增 |
| `FORMAL_PNG_NEEDED` | 旧运行表现可见，但正式 PNG 仍缺失或未接入 |
| `DONE_POLISH_PASS` | 已完成一轮正式分镜级强化 |
| `STYLE_LOCKED` | 节点构图、色板、叙事焦点已经定稿 |
| `FORMAL_SOURCE_READY` | 已有可作为正式质量母版的参考图或精修稿 |
| `RUNTIME_EXPORT_READY` | 正式母版已转为合规高质量 PNG 运行资源 |
| `IN_GAME_ACCEPTED` | 已在 NarrativeDemo / MainVisual 截图验收通过 |
| `SHOWCASE_READY` | 可用于对外截图、商店页或宣传材料 |
| `P0` | 当前 MVP 主流程优先处理 |
| `P1` | 主流程可后置优化，或已有资源但需精修 |
| `P2` | reserved 节点规划，暂不优先 |

正式美术阶段的目标不是继续新增 `NEEDS_ASSET`，而是把序章和 P0 主流程从“旧运行资源可见”推进到“高质量 PNG 实机验收”：

```text
STYLE_LOCKED → FORMAL_SOURCE_READY → RUNTIME_EXPORT_READY(PNG) → IN_GAME_ACCEPTED
```

---

## 3. 序章十二拍矩阵：黑海潮生

源头：`tables/narrative_mvp_prologue_steps.tsv`
运行：`data/narrative_mvp_nodes.json.prologue.steps`

| order | step_id | column | 视觉主题 | 已有 / 相关资源 | 当前状态 | 下一步 |
|---:|---|---|---|---|---|---|
| 1 | `black_tide` | 旧村 | 黑、潮声、奔跑 | `formal/prologue/01_black_tide.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `black_tide_0` |
| 2 | `father` | 旧村 | 父亲把主角按进柴堆，别出声 | `formal/prologue/02_father.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `black_tide_1` |
| 3 | `door` | 旧村 | 刀背敲门，东西在哪 | `formal/prologue/03_door.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `black_tide_2` |
| 4 | `dead` | 旧村 | 死人也不知道，潮声停顿 | `formal/prologue/04_dead.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `black_tide_dead` |
| 5 | `wooden_blade` | 旧村 | 木刀打在甲片上，零声 | `formal/prologue/05_wooden_blade.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `black_tide_wooden_blade` |
| 6 | `fall` | 旧村 | 火光高、父亲无声、母亲鞋停在火边 | `formal/prologue/06_fall.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `black_tide_fall` |
| 7 | `master_arrives` | 救场 | 旧甲味、挡眼、还活着、换我 | `formal/prologue/07_master_arrives.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `prologue_master_arrives` |
| 8 | `three_cards` | 救场 | 刀、步、断气 | `formal/prologue/08_three_cards.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入；墨迹符号需人工复核不可读 |
| 9 | `military_word` | 旧案 | 敌人口吐“军……”，箭到 | `formal/prologue/09_military_word.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `prologue_military_word` |
| 10 | `hidden_arrow` | 旧案 | 箭从黑处来，不是海上，不是倭人 | `formal/prologue/10_hidden_arrow.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `prologue_hidden_arrow` |
| 11 | `dont_look` | 旧案 | 老兵说别看，自己一直看黑箭 | `formal/prologue/11_dont_look.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `prologue_dont_look` |
| 12 | `departure` | 出山 | 十年，学刀学枪学活，师父还刀 | `formal/prologue/12_departure.png` | `FORMAL_PNG_GENERATED` + `TRACK_WIRED` | 正式 PNG 已接入 `departure` |

---

## 4. MVP 主流程节点矩阵

以下以 `tables/narrative_mvp_node_status.tsv` 的 `flow_enabled=true` 为 P0/P1 依据。

| flow_order | node_id | type | TSV 视觉意象 | runtime | visual_path | 当前美术状态 | 优先级 | 下一步 |
|---:|---|---|---|---|---|---|---|---|
| 10 | `military_order` | 事件 | 军令压案、墨未干、旧案不得声张、师父没有抬头 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_military_order.png` | `VISUAL_WIRED` + `TRACK_WIRED`；军令封印 / 海防图双焦点已进演出 | `P0` | 后续做截图验收与 UI 包装 |
| 20 | `beach_ambush` | 普通战斗 | 整齐脚印、像营里走出来、芦苇枪尖、官泥 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png` | `VISUAL_WIRED` + `TRACK_WIRED`；官泥脚印 / 倭伏兵剪影已进演出 | `P0` | 截图验收 |
| 30 | `beach_ambush_aftermath` | 战后处理 | 沙滩、尸体、脚印还在、割首/搜身/掩埋 | `RUNTIME_PRESENT` | 与 `beach_ambush` 复用 | `TRACK_WIRED`；官泥脚印 / 搜身证据已接入 | `P0` | 截图验收 |
| 40 | `fishing_village_embers` | 普通战斗 | 残村、黑烟、孩子咳嗽、船未靠岸、村心先烧 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png` | `VISUAL_WIRED`；剧情背景已补齐并通过资源校验 | `P0` | 后续截图验收 |
| 50 | `fishing_village_embers_aftermath` | 战后处理 | 黑烟渐低、村后火痕、追人/救人/看火 | `RUNTIME_PRESENT` | 与 `fishing_village_embers` 复用 | `TRACK_WIRED`；焦碗 / 咳嗽孩子剪影已接入 | `P0` | 后续拆专属 aftermath 背景 |
| 60 | `ming_firearm` | 旧物 | 倭船舱、木箱半开、官造火器、保养很好、新封泥 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/relics/relic_ming_firearm.png` | `VISUAL_WIRED` + `TRACK_WIRED`；火器刻印 / 火器箱双焦点已进演出 | `P0` | 截图验收 |
| 70 | `altered_military_report` | 旧物 | 破庙、倒神像、香炉下军报、墨比血新 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/relics/relic_altered_military_report.png` | `VISUAL_WIRED` + `TRACK_WIRED`；涂改军报 / 倒神像剪影已进演出 | `P0` | 后续截图验收 |
| 80 | `transport_officer` | 精英战斗 | 山道空车、深车辙、不该翻箱、袖口半页名册 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/portraits/transport_officer.png` | `TRACK_WIRED`；押运官剪影 / 半页湿名册已接入 | `P0` | 截图验收 |
| 90 | `transport_officer_aftermath` | 战后处理 | 空车、半页湿名册、押运官还活着、交给谁 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_transport_officer_aftermath.png` | `VISUAL_WIRED` + `TRACK_WIRED`；专属空车背景 / 湿名册 / 押运官剪影已接入 | `P0` | 截图验收 |
| 100 | `night_knife_camp` | 事件 | 深夜磨旧刀、火器刻印、师父手停、见过、再问人会死 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_night_knife_camp.png` | `VISUAL_WIRED` + `TRACK_WIRED`；火器刻印 / 旧刀 / 磨刀师父剪影已进演出 | `P0` | 截图验收 |
| 110 | `wakou_boss` | Boss | 破船、火器箱、倭首坐箱、看岸上、军门火漆 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/portraits/wakou_leader.png` | `TRACK_WIRED`；火器箱 / 军门火漆 / 倭首剪影已进 Boss 演出 | `P1` | 截图验收 |
| 120 | `military_coverup` | 结尾 | 军门灯火、缺页案卷、朱批、木匣不见、师父站门外 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_military_coverup.png` | `VISUAL_WIRED` + `TRACK_WIRED`；空木匣 / 缺页案卷 / 门外师父已进压案演出 | `P0` | 进入游戏内截图验收 |

---

## 5. Reserved 节点矩阵

这些节点存在于剧情源表，但当前 `flow_enabled=false`，不进入 MVP 主流程。

| node_id | type | TSV 视觉意象 | 当前状态 | 建议优先级 |
|---|---|---|---|---|
| `merchant_banquet` | 事件 | 雨夜海商宅、热酒冷兵、屏风后火器箱、酒盏旁钥匙 | `VISUAL_READY` + `TRACK_WIRED`；宴席背景 / 火器箱 / 酒盏钥匙已备 | `P2`：解除 reserved 后可直接进流程 |
| `mutiny_camp` | 精英战斗 | 营门、军旗、无粮、饷银没到、举枪不是为海寇 | `VISUAL_READY` + `TRACK_WIRED`；战斗背景 / 湿账册 / 饥兵剪影已备 | `P2`：解除 reserved 后可直接进流程 |
| `mutiny_camp_aftermath` | 战后处理 | 跪下的人、军粮仍无、写成反/饥/账 | `VISUAL_READY` + `TRACK_WIRED`；战后背景 / 湿账册 / 跪兵剪影已备 | `P2`：解除 reserved 后可直接进流程 |
| `military_messenger` | 事件 | 雨中信使、马比人先喘、信封无封泥、第二封信 | `VISUAL_READY` + `TRACK_WIRED`；雨中信使背景 / 无封泥书信 / 信使剪影已备 | `P2`：解除 reserved 后可直接进流程 |

---

## 6. 战斗背景矩阵

| battle_id | label | background | 对应节点 | 当前状态 | 备注 |
|---|---|---|---|---|---|
| `prologue_master_rescue` | 黑潮救援 | `battle_bg_black_tide.png` | `master_arrives` | `DONE_POLISH_PASS` | 已有师父挡箭、箭线、远火村影 |
| `first_act_beach_ambush` | 海边伏击 | `battle_bg_coast_ambush.png` | `beach_ambush` | `DONE_POLISH_PASS` | 已有暗礁、倭影、斜向暗箭 |
| `first_act_fishing_village_embers` | 渔村残火 | `battle_bg_fishing_village_embers.png` | `fishing_village_embers` | `DONE_POLISH_PASS` | 已有残村、黑烟、孩子线索、村后火 |
| `first_act_transport_officer` | 押运官对峙 | `battle_bg_transport_road.png` | `transport_officer` | `DONE_POLISH_PASS` | 已有空车、断封条、散落军械、车辙 |
| `first_act_mutiny_camp` | 欠饷营门 | `battle_bg_mutiny_camp.png` | `mutiny_camp` | `DONE_POLISH_PASS` | 当前节点 reserved，背景资源保留 |
| `first_act_wakou_boss` | 破船决战 | `battle_bg_broken_ship.png` | `wakou_boss` | `DONE_POLISH_PASS` | 已有破船、火器箱、倭首、岸上暗箭 |
| `test_spearman_duel` | 枪术试战 | `battle_bg_training_ground.png` | 测试 | `DONE_POLISH_PASS` | 已有枪架、刀靶、校场木架 |
| `test_blademaster_duel` | 刀术试战 | `battle_bg_training_ground.png` | 测试 | `DONE_POLISH_PASS` | 与枪术共用 |
| `fallback` | 默认接敌 | `battle_bg_training_ground.png` | fallback | `DONE_BASE` | 可保持 |

---

## 7. 已有叙事资源池

### 7.1 Props

| 资源 | 适用节点 | 当前状态 | 注意 |
|---|---|---|---|
| `assets/narrative/props/prop_casefile_missing_page.png` | `military_coverup` | `TRACK_WIRED` | 已作为军门压案第二焦点接入 |
| `assets/narrative/props/prop_firearm_crate.png` | `ming_firearm`、`wakou_boss`、`merchant_banquet` | `TRACK_WIRED` | 已接入明制火器、Boss 和海商宴演出 |
| `assets/narrative/props/prop_unsealed_letter.png` | `military_messenger` | `TRACK_WIRED` | 已接入雨中信使 reserved 演出轨 |
| `assets/narrative/props/prop_old_master_saber.png` | `departure`、`night_knife_camp` | `TRACK_WIRED` | 已接入 `departure` 演出轨，夜半磨刀后续可做第二焦点 |
| `assets/narrative/props/prop_firearm_seal_mark.png` | `ming_firearm`、`night_knife_camp` | `TRACK_WIRED` | 已接入火器旧物与夜半磨刀演出轨 |
| `assets/narrative/props/prop_half_roster_wet.png` | `transport_officer_aftermath` | `TRACK_WIRED` | 已接入押运官战后演出轨 |
| `assets/narrative/props/prop_empty_wooden_case.png` | `military_coverup` | `TRACK_WIRED` | 已接入军门压案演出轨 |
| `assets/narrative/props/prop_military_order_seal.png` | `military_order` | `TRACK_WIRED` | 已接入军令节点演出轨 |
| `assets/narrative/props/prop_official_mud_bootprint.png` | `beach_ambush`、`beach_ambush_aftermath` | `TRACK_WIRED` | 已接入海边伏击与战后脚印焦点 |
| `assets/narrative/props/prop_burnt_bowl.png` | `fishing_village_embers_aftermath` | `TRACK_WIRED` | 已接入渔村战后焦点 |
| `assets/narrative/props/prop_altered_military_report.png` | `altered_military_report` | `TRACK_WIRED` | 已接入涂改军报旧物演出轨 |
| `assets/narrative/props/prop_coastal_patrol_map.png` | `military_order`、后续军门线 | `TRACK_WIRED` | 已作为军令节点第二焦点接入 |
| `assets/narrative/props/prop_knife_at_door.png` | 序章 `door` | `TRACK_WIRED` | 已接入刀背敲门演出轨 |
| `assets/narrative/props/prop_wooden_training_blade.png` | 序章 `wooden_blade` | `TRACK_WIRED` | 已接入木刀零声演出轨 |
| `assets/narrative/props/prop_mother_shoe_by_fire.png` | 序章 `fall` | `TRACK_WIRED` | 已接入火边母亲鞋演出轨 |
| `assets/narrative/props/prop_black_arrow.png` | 序章 `hidden_arrow` | `TRACK_WIRED` | 已接入黑箭演出轨 |
| `assets/narrative/props/prop_beach_body_search.png` | `beach_ambush_aftermath` | `TRACK_WIRED` | 已接入海边战后搜身证据 |
| `assets/narrative/props/prop_military_lacquer_mark.png` | `wakou_boss` | `TRACK_WIRED` | 已接入 Boss 军门火漆焦点 |
| `assets/narrative/props/prop_wine_cup_key.png` | `merchant_banquet` | `TRACK_WIRED` | 已接入海商宴酒盏钥匙焦点 |
| `assets/narrative/props/prop_wet_payroll_ledger.png` | `mutiny_camp`、`mutiny_camp_aftermath` | `TRACK_WIRED` | 已接入欠饷账册焦点 |

### 7.2 Silhouettes

| 资源 | 适用节点 | 当前状态 | 注意 |
|---|---|---|---|
| `assets/narrative/silhouettes/sil_master_blocks_arrow.png` | 序章 `master_arrives` / `hidden_arrow` | `TRACK_WIRED` | 已接入 `master_rescue` 演出轨 |
| `assets/narrative/silhouettes/sil_wakou_ambusher.png` | `beach_ambush` | `TRACK_WIRED` | 已接入海边伏击第三焦点 |
| `assets/narrative/silhouettes/sil_transport_officer_shadow.png` | `transport_officer` / `transport_officer_aftermath` | `TRACK_WIRED` | 已接入押运官与战后处理演出轨 |
| `assets/narrative/silhouettes/sil_starving_soldier_shadow.png` | `mutiny_camp` | `TRACK_WIRED` | 已接入欠饷营 reserved 演出轨 |
| `assets/narrative/silhouettes/sil_wakou_boss_shadow.png` | `wakou_boss` | `TRACK_WIRED` | 已接入 Boss 第三焦点 |
| `assets/narrative/silhouettes/sil_grinding_saber_shadow.png` | `night_knife_camp` | `TRACK_WIRED` | 已作为夜半磨刀第三焦点接入 |
| `assets/narrative/silhouettes/sil_coughing_child_shadow.png` | `fishing_village_embers_aftermath` | `TRACK_WIRED` | 已作为渔村战后第三焦点接入 |
| `assets/narrative/silhouettes/sil_master_at_gate_shadow.png` | `military_coverup` | `TRACK_WIRED` | 已作为军门压案第三焦点接入 |
| `assets/narrative/silhouettes/sil_fallen_shrine_shadow.png` | `altered_military_report` | `TRACK_WIRED` | 已作为涂改军报第三焦点接入 |
| `assets/narrative/silhouettes/sil_father_hiding_child.png` | 序章 `father` | `TRACK_WIRED` | 已接入父亲藏子演出轨 |
| `assets/narrative/silhouettes/sil_master_looking_at_black_arrow.png` | 序章 `dont_look` | `TRACK_WIRED` | 已接入师父看黑箭演出轨 |
| `assets/narrative/silhouettes/sil_kneeling_mutiny_soldier.png` | `mutiny_camp_aftermath` | `TRACK_WIRED` | 已接入欠饷营战后跪兵演出轨 |
| `assets/narrative/silhouettes/sil_rain_messenger_shadow.png` | `military_messenger` | `TRACK_WIRED` | 已接入雨中信使演出轨 |

### 7.3 Route Portraits

| 资源 | 适用路线 | 当前状态 | 注意 |
|---|---|---|---|
| `assets/pixel_battle/portraits/hero_officer_spear_bust.png` | 枪手路线 / `player_profile.role=spearman` | `RUNTIME_EXPORT_READY` + `RUNTIME_WIRED` | 已接入 NarrativeDemo 焦点半身层；长枪必须与中远距枪牌动作绑定 |
| `assets/pixel_battle/portraits/hero_officer_saber_bust.png` | 刀客路线 / `player_profile.role=blademaster` | `RUNTIME_EXPORT_READY` + `RUNTIME_WIRED` | 已接入 NarrativeDemo 焦点半身层；腰刀必须与近距刀牌动作绑定 |
| `assets/pixel_battle/portraits/performance_hero_spear.png` | 枪手路线 / 演出 hero layer | `RUNTIME_EXPORT_READY` + `RUNTIME_WIRED` | 已接入 CinematicPerformance hero 层，随 player profile 切换 |
| `assets/pixel_battle/portraits/performance_hero_saber.png` | 刀客路线 / 演出 hero layer | `RUNTIME_EXPORT_READY` + `RUNTIME_WIRED` | 已接入 CinematicPerformance hero 层，随 player profile 切换 |

主角路线图像接线规则：

```text
spearman → hero_officer_spear_bust.png + performance_hero_spear.png
blademaster → hero_officer_saber_bust.png + performance_hero_saber.png
```

当前状态是运行层已落地，下一步进入 `IN_GAME_ACCEPTED` 截图验收。两版必须继续保持同脸同甲，不能在后续动作包或战斗站姿中分裂成两名角色。

---

## 8. 当前 P0 闭环清单

当前 P0 缺口已经按 `docs/ART_PRODUCTION_ROADMAP.md` 收口。新的最小立即执行包改为“序章 PNG 化 + 截图验收”，不再以 SVG 接线完成作为正式质量终点：

```text
assets/pixel_battle/backgrounds/narrative_night_knife_camp.png
assets/narrative/props/prop_old_master_saber.png
assets/narrative/props/prop_firearm_seal_mark.png
assets/narrative/props/prop_half_roster_wet.png
assets/narrative/props/prop_empty_wooden_case.png
tables/narrative_mvp_node_status.tsv
docs/NODE_VISUAL_MATRIX.md
```

### 8.1 P0 道具 / 剪影收口

```text
P0 序章、证据链、战后处理所列道具 / 剪影已生成并接入 performance_tracks。
reserved 节点资源仍作为 P2 规划，不抢主流程。
```

已接入 performance_tracks 的 P0 props：

```text
prop_old_master_saber.png
prop_firearm_seal_mark.png
prop_half_roster_wet.png
prop_empty_wooden_case.png
prop_military_order_seal.png
prop_official_mud_bootprint.png
prop_burnt_bowl.png
prop_altered_military_report.png
```

当前 P0 evidence props 与核心剪影均已进入 `performance_tracks`。reserved/P2 的海商宴、欠饷营、雨中信使也已预接线；剩余工作主要是把正式用途的资源切到 PNG 并截图验收。

### 8.2 已确认的主流程 visual_path

```text
res://assets/pixel_battle/backgrounds/narrative_military_order.png
res://assets/pixel_battle/backgrounds/narrative_beach_ambush.png
res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.png
res://assets/pixel_battle/relics/relic_ming_firearm.png
res://assets/pixel_battle/relics/relic_altered_military_report.png
res://assets/pixel_battle/portraits/transport_officer.png
res://assets/pixel_battle/portraits/wakou_leader.png
res://assets/pixel_battle/backgrounds/narrative_military_coverup.png
res://assets/pixel_battle/backgrounds/narrative_merchant_banquet.png
res://assets/pixel_battle/backgrounds/battle_bg_mutiny_camp.png
res://assets/pixel_battle/backgrounds/narrative_mutiny_camp_aftermath.png
res://assets/pixel_battle/backgrounds/narrative_military_messenger.png
```

已完成专项替换：

```text
night_knife_camp → res://assets/pixel_battle/backgrounds/narrative_night_knife_camp.png
transport_officer_aftermath → res://assets/pixel_battle/backgrounds/narrative_transport_officer_aftermath.png
```

---

## 9. 编译差异口径

`node_status.tsv` 中以下战后节点为主流程 playable；编译产物会把部分战后处理合并进前一战斗节点的后续碎片：

```text
beach_ambush_aftermath
fishing_village_embers_aftermath
transport_officer_aftermath
```

处理策略：

1. 不为合并节点额外硬写 GDScript 背景。
2. 以 `performance_tracks` 挂接战后证据焦点。
3. 若后续恢复独立节点，再补专属 aftermath visual_path。

---

## 10. 下一步执行顺序

### Step 1：序章全流程 PNG 化

```text
1. 按“序章十二拍矩阵”逐拍确认正式 PNG 是否存在于 assets。
2. 优先复用已生成的 prologue_*、battle_bg_black_tide、prop_*、sil_* PNG。
3. `dead`、`three_cards`、`military_word` 如无专图，补最小正式 PNG 焦点，不再用“无 / 抽象 P2”收口。
4. 修改 TSV 的 visual_path / performance asset path，运行 compile_tables.py。
5. NarrativeDemo 走完整序章，关闭 debug，截图确认没有占位、低清图、UI 遮挡。
```

### Step 2：5 张展示级截图验收

```text
1. 截取黑潮救援、海边伏击、渔村残火、夜半磨刀、军门压案 5 张目标图。
2. 检查多焦点演出不遮挡剧情 UI。
3. 若发现遮挡，优先调 performance_timeline.tsv 中的焦点位置与 scale。
4. 截图通过后，对应节点推进到 IN_GAME_ACCEPTED。
```

### Step 3：P0 节点正式质量推进

| 顺序 | 节点 | 当前状态 | 正式质量下一步 |
|---:|---|---|---|
| 1 | `night_knife_camp` | `RUNTIME_WIRED` | 做正式源画标杆，锁深夜湿地、旧刀、火器刻印、师父停手 |
| 2 | `military_coverup` | `RUNTIME_WIRED` | 强化案卷缺页、空木匣、朱批和门外师父 |
| 3 | `beach_ambush` | `RUNTIME_WIRED` | 强化官泥脚印、芦苇枪尖、敌人军伍感 |
| 4 | `fishing_village_embers` | `RUNTIME_WIRED` | 强化村心先烧、孩子线索、村后火痕 |
| 5 | `ming_firearm` | `RUNTIME_WIRED` | 强化官造刻印、新封泥、火器保养感 |
| 6 | `transport_officer_aftermath` | `RUNTIME_WIRED` | 强化空车、湿名册、押运官恐惧 |
| 7 | `wakou_boss` | `RUNTIME_WIRED` | 强化破船、火器箱、军门火漆、岸上暗箭 |

### Step 4：UI / 角色正式精修

已具备并接入 NarrativeDemo 可见层：

```text
assets/pixel_battle/portraits/hero_officer_bust.png
assets/pixel_battle/portraits/master_veteran_bust.png
assets/pixel_battle/portraits/wakou_boss_bust.png
assets/pixel_battle/ui/ui_casefile_panel.png
assets/pixel_battle/ui/ui_military_order_badge.png
assets/pixel_battle/ui/ui_strategy_book_tabs.png
assets/pixel_battle/ui/title_canghai_diming.png
assets/pixel_battle/backgrounds/map_march_coast.png
```

下一步不是继续接线，而是提升：

```text
角色半身辨识度
UI 框体材质
标题字展示级字形
地图底纹和节点符号
```

主角双路线已经完成第一轮运行拆分，后续精修转入截图和动作包一致性：

| 角色资源目标 | 路线 | 武器 | 招式视觉绑定 |
|---|---|---|---|
| `hero_officer_spear` | 戚家军枪手 | 明代军用长枪 | `steady_step`、`mid_spear`、`chain_thrust`、`pinning_hold`、`dragon_break` |
| `hero_officer_saber` | 单刀快手 | 明代腰刀 / 单刀 | `rush_step`、`sidestep`、`swift_cut`、`cross_slash`、`dragonslash` |

两版主角在截图、半身、战斗站姿中必须保持同脸同甲，只允许武器和姿态变化。

### Step 5：reserved / P2 节点规划

`merchant_banquet`、`mutiny_camp`、`military_messenger` 暂不抢当前 MVP 主流程；资源和 track 已备，需要推进时只需从 `node_status.tsv` 解除 reserved 并给出 flow_order。

---

## 11. 视觉一致性检查清单

每新增或替换一个节点美术资源，必须检查：

```text
1. node_id 是否存在于 tables/narrative_mvp_nodes.tsv？
2. node_id 在 node_status.tsv 中是 flow_enabled=true 还是 reserved？
3. 当前 visual_path 是什么？是否复用？
4. data/narrative_mvp_nodes.json 是否运行可读到该节点？
5. 如果是 aftermath，运行层是否独立存在？
6. 是否存在一个可记忆物件？
7. 是否只留下线索，而不是直接解释阴谋？
8. PNG 是否本地、清晰、无水印、无多余文字，且不是 `art_reference/generated` 草图？
9. 背景内是否没有标题文字？
10. 是否没有新增第二套背景层？
11. 是否没有把路径写死到 GDScript？
12. 是否兼容当前 visual_path 体系？
```
