# 《大明之沧海嘀鸣》节点视觉矩阵

> 版本：v0.5  
> 对齐分支：`main`  
> 更新时间：按《美术规划.pdf》review 后，结合 narrative TSV / node_status / 编译产物重新校准  
> 用途：统一剧情源头、MVP 流程、visual_path、战斗背景、叙事道具和后续挂接优先级。

---

## 0. 执行入口

本矩阵只负责“节点级状态”。生产节奏和阶段交付见：

```text
docs/ART_PRODUCTION_ROADMAP.md
```

三份文档分工：

| 文档 | 作用 |
|---|---|
| `ART_DIRECTION_GUIDE.md` | 美术目标、风格边界、色彩、构图、禁止事项 |
| `NODE_VISUAL_MATRIX.md` | 每个 node / battle_id / visual_path / 资源状态 |
| `ART_PRODUCTION_ROADMAP.md` | 阶段计划、P0/P1/P2 交付包、验收路线 |

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
| `ASSET_READY_UNWIRED` | 资源已存在，但尚未作为 `visual_path` 或 performance track 挂接 |
| `NEEDS_ASSET` | 资源缺失，需要新增 |
| `DONE_POLISH_PASS` | 已完成一轮正式分镜级强化 |
| `P0` | 当前 MVP 主流程优先处理 |
| `P1` | 主流程可后置优化，或已有资源但需精修 |
| `P2` | reserved 节点规划，暂不优先 |

---

## 3. 序章十二拍矩阵：黑海潮生

源头：`tables/narrative_mvp_prologue_steps.tsv`  
运行：`data/narrative_mvp_nodes.json.prologue.steps`

| order | step_id | column | 视觉主题 | 已有 / 相关资源 | 当前状态 | 下一步 |
|---:|---|---|---|---|---|---|
| 1 | `black_tide` | 旧村 | 黑、潮声、奔跑 | `battle_bg_black_tide.svg` 可借用色调 | `RUNTIME_PRESENT` | 保持 |
| 2 | `father` | 旧村 | 父亲把主角按进柴堆，别出声 | 无 | `RUNTIME_PRESENT` + `NEEDS_ASSET` | 补 `sil_father_hiding_child.svg` |
| 3 | `door` | 旧村 | 刀背敲门，东西在哪 | 无 | `RUNTIME_PRESENT` + `NEEDS_ASSET` | 补门影 / 刀背敲门 prop |
| 4 | `dead` | 旧村 | 死人也不知道，潮声停顿 | 无 | `RUNTIME_PRESENT` | P2 抽象暗层 |
| 5 | `wooden_blade` | 旧村 | 木刀打在甲片上，零声 | 无 | `RUNTIME_PRESENT` + `NEEDS_ASSET` | 补 `prop_wooden_training_blade.svg` |
| 6 | `fall` | 旧村 | 火光高、父亲无声、母亲鞋停在火边 | 无 | `RUNTIME_PRESENT` + `NEEDS_ASSET` | P0 补 `prop_mother_shoe_by_fire.svg` |
| 7 | `master_arrives` | 救场 | 旧甲味、挡眼、还活着、换我 | `sil_master_blocks_arrow.svg` | `RUNTIME_PRESENT` + `ASSET_READY_UNWIRED` | 挂接到序章演出 |
| 8 | `three_cards` | 救场 | 刀、步、断气 | 无 | `RUNTIME_PRESENT` | P2 补刀谱 / 三卡抽象 prop |
| 9 | `military_word` | 旧案 | 敌人口吐“军……”，箭到 | `battle_bg_black_tide.svg` 有箭线语法 | `RUNTIME_PRESENT` | P2 补断字焦点 |
| 10 | `hidden_arrow` | 旧案 | 箭从黑处来，不是海上，不是倭人 | `sil_master_blocks_arrow.svg` 可复用箭线 | `RUNTIME_PRESENT` | 保持 / 后续补黑箭 prop |
| 11 | `dont_look` | 旧案 | 老兵说别看，自己一直看黑箭 | 无 | `RUNTIME_PRESENT` + `NEEDS_ASSET` | 补 `sil_master_looking_at_black_arrow.svg` |
| 12 | `departure` | 出山 | 十年，学刀学枪学活，师父还刀 | 无 | `RUNTIME_PRESENT` + `NEEDS_ASSET` | P0 补 `prop_old_master_saber.svg` |

---

## 4. MVP 主流程节点矩阵

以下以 `tables/narrative_mvp_node_status.tsv` 的 `flow_enabled=true` 为 P0/P1 依据。

| flow_order | node_id | type | TSV 视觉意象 | runtime | visual_path | 当前美术状态 | 优先级 | 下一步 |
|---:|---|---|---|---|---|---|---|---|
| 10 | `military_order` | 事件 | 军令压案、墨未干、旧案不得声张、师父没有抬头 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_military_order.svg` | `VISUAL_WIRED`，但缺军令 / 海防图 props | `P0` | 补 `prop_military_order_seal.svg`、`prop_coastal_patrol_map.svg`；检查 visual_path 资源完成度 |
| 20 | `beach_ambush` | 普通战斗 | 整齐脚印、像营里走出来、芦苇枪尖、官泥 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_beach_ambush.svg` | 战斗背景 `DONE_POLISH_PASS`；剧情图需核查 | `P0` | 补 `prop_official_mud_bootprint.svg`；挂 `sil_wakou_ambusher.svg` |
| 30 | `beach_ambush_aftermath` | 战后处理 | 沙滩、尸体、脚印还在、割首/搜身/掩埋 | `RUNTIME_MERGED_OR_ABSENT`：JSON 中当前未独立列出该 node | 与 `beach_ambush` 复用 | `VISUAL_REUSED` | `P0` | 若编译后恢复独立节点，应补专属 aftermath visual；先规划尸体脚印 / 搜身证据 prop |
| 40 | `fishing_village_embers` | 普通战斗 | 残村、黑烟、孩子咳嗽、船未靠岸、村心先烧 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.svg` | 战斗背景 `DONE_POLISH_PASS`；剧情图需核查 | `P0` | 补 `sil_coughing_child_shadow.svg`、村后火痕 focus |
| 50 | `fishing_village_embers_aftermath` | 战后处理 | 黑烟渐低、村后火痕、追人/救人/看火 | `RUNTIME_MERGED_OR_ABSENT`：JSON 中当前未独立列出该 node | 与 `fishing_village_embers` 复用 | `VISUAL_REUSED` | `P0` | 补 `prop_burnt_bowl.svg`、村后火痕专属图；确认编译产物结构 |
| 60 | `ming_firearm` | 旧物 | 倭船舱、木箱半开、官造火器、保养很好、新封泥 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/relics/relic_ming_firearm.svg` | `VISUAL_WIRED`，已有 `prop_firearm_crate.svg` 未挂 | `P0` | 补 `prop_firearm_seal_mark.svg`；检查 relic 图是否需要替换为正式版 |
| 70 | `altered_military_report` | 旧物 | 破庙、倒神像、香炉下军报、墨比血新 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/relics/relic_altered_military_report.svg` | `VISUAL_WIRED`，但缺专属涂改军报 prop | `P0` | 补 `prop_altered_military_report.svg`、倒神像剪影 |
| 80 | `transport_officer` | 精英战斗 | 山道空车、深车辙、不该翻箱、袖口半页名册 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/portraits/transport_officer.svg` | 战斗背景 `DONE_POLISH_PASS`；已有押运官剪影未挂 | `P0` | 补 `prop_half_roster_wet.svg`；挂 `sil_transport_officer_shadow.svg` |
| 90 | `transport_officer_aftermath` | 战后处理 | 空车、半页湿名册、押运官还活着、交给谁 | `RUNTIME_MERGED_OR_ABSENT`：JSON 当前未独立列出该 node | 与 `transport_officer` 复用 | `VISUAL_REUSED` | `P0` | 补半页湿名册、空车 aftermath visual；确认编译产物结构 |
| 100 | `night_knife_camp` | 事件 | 深夜磨旧刀、火器刻印、师父手停、见过、再问人会死 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/prologue_departure.svg` | `VISUAL_REUSED`，当前用出山背景不够准确 | `P0` | 执行 `ART_PRODUCTION_ROADMAP.md` P0：新增 `narrative_night_knife_camp.svg`、旧刀 / 火器刻印 prop，并替换 visual_path |
| 110 | `wakou_boss` | Boss | 破船、火器箱、倭首坐箱、看岸上、军门火漆 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/portraits/wakou_leader.svg` | 战斗背景 `DONE_POLISH_PASS`；已有 Boss 剪影 / 火器箱未挂 | `P1` | 补军门火漆 focus；挂 `sil_wakou_boss_shadow.svg`、`prop_firearm_crate.svg` |
| 120 | `military_coverup` | 结尾 | 军门灯火、缺页案卷、朱批、木匣不见、师父站门外 | `RUNTIME_PRESENT` | `res://assets/pixel_battle/backgrounds/narrative_military_coverup.svg` | `VISUAL_WIRED`，已有缺页案卷未挂 | `P0` | 补 `prop_empty_wooden_case.svg`、门外师父剪影；挂 `prop_casefile_missing_page.svg` |

---

## 5. Reserved 节点矩阵

这些节点存在于剧情源表，但当前 `flow_enabled=false`，不进入 MVP 主流程。

| node_id | type | TSV 视觉意象 | 当前状态 | 建议优先级 |
|---|---|---|---|---|
| `merchant_banquet` | 事件 | 雨夜海商宅、热酒冷兵、屏风后火器箱、酒盏旁钥匙 | 已有 `prop_firearm_crate.svg` 可用，但未挂 | `P2`：先规划，暂不抢 P0 |
| `mutiny_camp` | 精英战斗 | 营门、军旗、无粮、饷银没到、举枪不是为海寇 | 战斗背景已 `DONE_POLISH_PASS`，但当前 reserved | `P2`：资源已备，暂不挂主流程 |
| `mutiny_camp_aftermath` | 战后处理 | 跪下的人、军粮仍无、写成反/饥/账 | 缺账本 / 跪兵资源 | `P2` |
| `military_messenger` | 事件 | 雨中信使、马比人先喘、信封无封泥、第二封信 | 已有 `prop_unsealed_letter.svg`，但节点 reserved | `P2` |

---

## 6. 战斗背景矩阵

| battle_id | label | background | 对应节点 | 当前状态 | 备注 |
|---|---|---|---|---|---|
| `prologue_master_rescue` | 黑潮救援 | `battle_bg_black_tide.svg` | `master_arrives` | `DONE_POLISH_PASS` | 已有师父挡箭、箭线、远火村影 |
| `first_act_beach_ambush` | 海边伏击 | `battle_bg_coast_ambush.svg` | `beach_ambush` | `DONE_POLISH_PASS` | 已有暗礁、倭影、斜向暗箭 |
| `first_act_fishing_village_embers` | 渔村残火 | `battle_bg_fishing_village_embers.svg` | `fishing_village_embers` | `DONE_POLISH_PASS` | 已有残村、黑烟、孩子线索、村后火 |
| `first_act_transport_officer` | 押运官对峙 | `battle_bg_transport_road.svg` | `transport_officer` | `DONE_POLISH_PASS` | 已有空车、断封条、散落军械、车辙 |
| `first_act_mutiny_camp` | 欠饷营门 | `battle_bg_mutiny_camp.svg` | `mutiny_camp` | `DONE_POLISH_PASS` | 当前节点 reserved，背景资源保留 |
| `first_act_wakou_boss` | 破船决战 | `battle_bg_broken_ship.svg` | `wakou_boss` | `DONE_POLISH_PASS` | 已有破船、火器箱、倭首、岸上暗箭 |
| `test_spearman_duel` | 枪术试战 | `battle_bg_training_ground.svg` | 测试 | `DONE_POLISH_PASS` | 已有枪架、刀靶、校场木架 |
| `test_blademaster_duel` | 刀术试战 | `battle_bg_training_ground.svg` | 测试 | `DONE_POLISH_PASS` | 与枪术共用 |
| `fallback` | 默认接敌 | `battle_bg_training_ground.svg` | fallback | `DONE_BASE` | 可保持 |

---

## 7. 已有叙事资源池

### 7.1 Props

| 资源 | 适用节点 | 当前状态 | 注意 |
|---|---|---|---|
| `assets/narrative/props/prop_casefile_missing_page.svg` | `military_coverup` | `ASSET_READY_UNWIRED` | 适合压案，不适合作为涂改军报主资源 |
| `assets/narrative/props/prop_firearm_crate.svg` | `ming_firearm`、`wakou_boss`、`merchant_banquet` | `ASSET_READY_UNWIRED` | `merchant_banquet` 当前 reserved |
| `assets/narrative/props/prop_unsealed_letter.svg` | `military_messenger` | `ASSET_READY_UNWIRED` | 节点当前 reserved，暂不 P0 |

### 7.2 Silhouettes

| 资源 | 适用节点 | 当前状态 | 注意 |
|---|---|---|---|
| `assets/narrative/silhouettes/sil_master_blocks_arrow.svg` | 序章 `master_arrives` / `hidden_arrow` | `ASSET_READY_UNWIRED` | 可挂序章演出 |
| `assets/narrative/silhouettes/sil_wakou_ambusher.svg` | `beach_ambush` | `ASSET_READY_UNWIRED` | 可挂海边伏击剧情图 |
| `assets/narrative/silhouettes/sil_transport_officer_shadow.svg` | `transport_officer` | `ASSET_READY_UNWIRED` | 可挂押运官 visual |
| `assets/narrative/silhouettes/sil_starving_soldier_shadow.svg` | `mutiny_camp` | `ASSET_READY_UNWIRED` | 节点当前 reserved |
| `assets/narrative/silhouettes/sil_wakou_boss_shadow.svg` | `wakou_boss` | `ASSET_READY_UNWIRED` | 可挂 Boss 演出 |

---

## 8. 当前 P0 缺口清单

当前 P0 缺口以 `docs/ART_PRODUCTION_ROADMAP.md` 为准。最小立即执行包：

```text
assets/pixel_battle/backgrounds/narrative_night_knife_camp.svg
assets/narrative/props/prop_old_master_saber.svg
assets/narrative/props/prop_firearm_seal_mark.svg
assets/narrative/props/prop_half_roster_wet.svg
assets/narrative/props/prop_empty_wooden_case.svg
tables/narrative_mvp_node_status.tsv
docs/NODE_VISUAL_MATRIX.md
```

### 8.1 仍需新增的 P0 道具 / 剪影

```text
prop_mother_shoe_by_fire.svg
prop_old_master_saber.svg
prop_military_order_seal.svg
prop_coastal_patrol_map.svg
prop_official_mud_bootprint.svg
prop_burnt_bowl.svg
prop_firearm_seal_mark.svg
prop_altered_military_report.svg
prop_half_roster_wet.svg
prop_empty_wooden_case.svg
sil_father_hiding_child.svg
sil_coughing_child_shadow.svg
sil_grinding_saber_shadow.svg
sil_master_looking_at_black_arrow.svg
```

### 8.2 需要检查 / 替换的 visual_path

```text
res://assets/pixel_battle/backgrounds/narrative_military_order.svg
res://assets/pixel_battle/backgrounds/narrative_beach_ambush.svg
res://assets/pixel_battle/backgrounds/narrative_fishing_village_embers.svg
res://assets/pixel_battle/relics/relic_ming_firearm.svg
res://assets/pixel_battle/relics/relic_altered_military_report.svg
res://assets/pixel_battle/portraits/transport_officer.svg
res://assets/pixel_battle/backgrounds/prologue_departure.svg
res://assets/pixel_battle/portraits/wakou_leader.svg
res://assets/pixel_battle/backgrounds/narrative_military_coverup.svg
```

尤其：

```text
night_knife_camp 当前复用 prologue_departure.svg，优先级最高，应替换成专属夜半磨刀 visual。
```

---

## 9. 需要确认的编译差异

`node_status.tsv` 中以下节点为主流程 playable，但当前 `data/narrative_mvp_nodes.json` 可能未作为独立 node 出现：

```text
beach_ambush_aftermath
fishing_village_embers_aftermath
transport_officer_aftermath
```

处理策略：

1. 先确认编译脚本是否应保留 aftermath 独立节点。
2. 若运行层确实合并，则美术不应盲目挂独立 visual_path。
3. 若后续恢复独立节点，则优先拆专属 aftermath visual。

---

## 10. 下一步执行顺序

### Step 1：执行 P0 night_knife_camp 包

```text
1. 参考 art_reference/generated/ref_night_knife_camp.png
2. 生成 narrative_night_knife_camp.svg
3. 生成 old_master_saber / firearm_seal_mark / half_roster_wet / empty_wooden_case SVG
4. 修改 night_knife_camp visual_path
5. 更新本矩阵状态
```

### Step 2：补证据链资源

优先：

```text
prop_altered_military_report.svg
prop_official_mud_bootprint.svg
prop_burnt_bowl.svg
prop_military_order_seal.svg
prop_coastal_patrol_map.svg
```

### Step 3：处理 aftermath 独立节点差异

先确认编译产物结构，再决定是否让 aftermath 独立出现在 runtime。

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
8. SVG 是否纯本地、无字体、无外链？
9. 背景内是否没有标题文字？
10. 是否没有新增第二套背景层？
11. 是否没有把路径写死到 GDScript？
12. 是否兼容当前 visual_path 体系？
```
