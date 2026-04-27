# 《大明之沧海嘀鸣》节点视觉矩阵

> 版本：v0.3  
> 对齐分支：`main`  
> 当前叙事源表：`tables/narrative_mvp_prologue_steps.tsv`、`tables/narrative_mvp_nodes.tsv`  
> 辅助参考：`data/battle_scene_manifest.json`、`data/performance_tracks.json`  
> 用途：统一 TSV node、battle_id、剧情演出 track、战斗背景、叙事道具和角色剪影状态。

---

## 1. 状态标记

| 状态 | 含义 |
|---|---|
| `DONE_BASE` | 已有基础资源或配置，能支撑 Demo 演示 |
| `DONE_POLISH_PASS` | 已完成一轮正式分镜级强化 |
| `TRACK_DONE` | `performance_tracks.json` 已有专属 timeline / beats |
| `TRACK_MISSING` | 当前缺少专属演出 track，可能走 fallback |
| `ASSET_READY_UNWIRED` | 资源已存在，但尚未挂接到演出配置 |
| `NEEDS_ASSET` | 资源缺失，需要新增 |
| `CONFIG_ONLY` | 当前只有 TSV 剧情配置或文案，没有对应美术资产 |
| `AFTERMATH` | 战后处理节点，重点是证据、选择和后果，不是战斗动作 |
| `LOCKED` | 当前阶段不建议继续改，除非发现明显问题 |

---

## 2. 当前叙事源表结构

当前应以 TSV 为准：

```text
tables/narrative_mvp_prologue_steps.tsv
tables/narrative_mvp_nodes.tsv
```

当前第一幕主节点数量为 16，不是旧版 12。

关键结构变化：

```text
beach_ambush → beach_ambush_aftermath
fishing_village_embers → fishing_village_embers_aftermath
transport_officer → transport_officer_aftermath
mutiny_camp → mutiny_camp_aftermath
```

战斗触发方式：

- 多数遭遇节点顶层 `combat_json.enabled=false`。
- 战斗通过 `choices_json` 中的 `combat` 字段触发。
- 美术矩阵仍需记录对应 battle_id，便于剧情视觉与战斗背景一致。

数值变量口径：

```text
military_merit
clean_reputation
case_clues
```

旧口径 `jun_gong / qing_wang / clues` 不再作为美术 UI 命名依据。

---

## 3. 序章十二拍矩阵：黑海潮生

| order | step_id | column | 视觉主题 | 演出状态 | 关键资源 / 缺口 | 下一步 |
|---:|---|---|---|---|---|---|
| 1 | `black_tide` | 旧村 | 黑、潮声、奔跑 | `TRACK_DONE`：`black_tide_0` | 黑潮背景已有 | 可保持 |
| 2 | `father` | 旧村 | 父亲把主角按进柴堆、别出声 | `TRACK_DONE`：`black_tide_1` | 缺 `sil_father_hiding_child.svg` | P1 补 |
| 3 | `door` | 旧村 | 刀背敲门、东西在哪 | `TRACK_DONE`：`black_tide_2` | 缺门影 / 刀背敲门 prop | P1 补 |
| 4 | `dead` | 旧村 | 死人也不知道、潮声停顿 | `TRACK_DONE`：`black_tide_3` | 缺死亡瞬间抽象暗层 | P2 |
| 5 | `wooden_blade` | 旧村 | 木刀打在甲片上，零声 | 复用黑潮段 | 缺 `prop_wooden_training_blade.svg` | P1 补 |
| 6 | `fall` | 旧村 | 火光高、父亲无声、母亲的鞋停在火边 | 复用黑潮段 | 缺 `prop_mother_shoe_by_fire.svg` | P0 补 |
| 7 | `master_arrives` | 救场 | 一只手挡眼、旧甲味、还活着、换我 | `TRACK_DONE`：`master_rescue` | `sil_master_blocks_arrow.svg` 已有但未挂接 | 挂接 |
| 8 | `three_cards` | 救场 | 刀、步、断气 | 复用演出 | 缺刀谱 / 三卡抽象 prop | P2 |
| 9 | `military_word` | 旧案 | 敌人口吐“军……”，箭到 | `TRACK_DONE`：`arrow_silence` | 缺“军”字断句焦点 | P2 |
| 10 | `hidden_arrow` | 旧案 | 箭从黑处来，不是海上，不是倭人 | `TRACK_DONE`：`arrow_silence` | 战斗背景已有箭线 | 可保持 |
| 11 | `dont_look` | 旧案 | 老兵说别看，自己一直看黑箭，后来叫他师父 | `TRACK_DONE`：`arrow_silence` | 缺老兵看黑箭剪影 | P1 补 |
| 12 | `departure` | 出山 | 十年，学刀学枪学活，师父还刀，该走了 | `TRACK_DONE`：`departure` | 缺 `prop_old_master_saber.svg` | P0 补 |

---

## 4. 第一幕 16 节点视觉矩阵

| order | node_id | 类型 | battle_id | 当前 TSV 视觉意象 | performance track | 已有资源 | 当前状态 | 下一步动作 |
|---:|---|---|---|---|---|---|---|---|
| 1 | `military_order` | 事件 | 无 | 军令压案、墨未干、旧案不得声张、师父没有抬头 | `TRACK_DONE`：`military_order` | 暂无军令 / 海防图 prop | `CONFIG_ONLY` + `TRACK_DONE` | 新增 `prop_military_order_seal.svg`、`prop_coastal_patrol_map.svg` |
| 2 | `beach_ambush` | 遭遇战前 | `first_act_beach_ambush` | 整齐脚印、像营里走出来、芦苇枪尖、官泥 | `TRACK_DONE`：`beach_ambush` | `sil_wakou_ambusher.svg` 已有但未挂接；战斗背景已强化 | `DONE_POLISH_PASS` + `ASSET_READY_UNWIRED` | 挂接伏击剪影；补 `prop_official_mud_bootprint.svg` |
| 3 | `beach_ambush_aftermath` | 战后处理 | 无 | 沙滩、尸体、脚印还在、割首/搜身/掩埋 | `TRACK_MISSING` | 暂无 aftermath 专用 prop | `AFTERMATH` + `NEEDS_ASSET` | 新增尸体脚印 / 麻袋首级 / 搜身证物焦点 |
| 4 | `fishing_village_embers` | 遭遇战前 | `first_act_fishing_village_embers` | 残村、黑烟、孩子咳嗽、船未靠岸、村心先烧、烟里刀光 | `TRACK_MISSING` | 战斗背景已强化，含孩子线索 | `DONE_POLISH_PASS` + `TRACK_MISSING` | 新增专属 track；补 `sil_coughing_child_shadow.svg` |
| 5 | `fishing_village_embers_aftermath` | 战后处理 | 无 | 黑烟渐低、村后火痕、追人/救人/看火 | `TRACK_MISSING` | 暂无 aftermath prop | `AFTERMATH` + `NEEDS_ASSET` | 新增 `prop_burnt_bowl.svg`、村后火痕焦点 |
| 6 | `merchant_banquet` | 事件 | 无 | 雨夜海商宅、热酒冷兵、屏风后火器箱、酒盏旁钥匙 | `TRACK_MISSING` | `prop_firearm_crate.svg` 已有但未挂接 | `CONFIG_ONLY` + `ASSET_READY_UNWIRED` | 新增 `sil_merchant_shadow.svg`、`prop_wine_cup_key.svg`、宴席背景 |
| 7 | `ming_firearm` | 线索 | 无 | 倭船舱、木箱半开、官造火器、保养很好、新封泥 | `TRACK_DONE`：`ming_firearm` | `prop_firearm_crate.svg` 已有但未挂接 | `TRACK_DONE` + `ASSET_READY_UNWIRED` | 新增 / 强化 `prop_firearm_seal_mark.svg`；挂接火器箱 |
| 8 | `altered_military_report` | 线索 | 无 | 破庙、倒神像、香炉下军报、涂改人数、墨比血新、少的是人 | `TRACK_MISSING` | `prop_casefile_missing_page.svg` 可复用但不准确 | `CONFIG_ONLY` + `TRACK_MISSING` | 新增 `prop_altered_military_report.svg`、倒神像剪影、专属 track |
| 9 | `transport_officer` | 遭遇战前 | `first_act_transport_officer` | 山道空车、深车辙、不该翻箱、袖口半页名册 | `TRACK_DONE`：`transport_officer` | `sil_transport_officer_shadow.svg` 已有；战斗背景已强化 | `DONE_POLISH_PASS` + `ASSET_READY_UNWIRED` | 挂接押运官剪影；新增半页名册露出焦点 |
| 10 | `transport_officer_aftermath` | 战后处理 | 无 | 空车、半页湿名册、押运官还活着、交给谁 | `TRACK_MISSING` | 暂无湿名册 prop | `AFTERMATH` + `NEEDS_ASSET` | 新增 `prop_half_roster_wet.svg`；专属 aftermath track |
| 11 | `mutiny_camp` | 遭遇战前 | `first_act_mutiny_camp` | 营门、军旗、无粮、饷银没到、营头举枪不是为了海寇 | `TRACK_MISSING` | `sil_starving_soldier_shadow.svg` 已有；战斗背景已强化 | `DONE_POLISH_PASS` + `TRACK_MISSING` | 新增专属 track；挂饥饿士兵剪影 / 空锅 focus |
| 12 | `mutiny_camp_aftermath` | 战后处理 | 无 | 营门仍在、军粮仍无、跪下的人、写成反/饥/账 | `TRACK_MISSING` | 暂无账本 prop | `AFTERMATH` + `NEEDS_ASSET` | 新增 `prop_soaked_payroll_book.svg`；跪兵剪影 |
| 13 | `military_messenger` | 事件 | 无 | 雨中信使、马比人先喘、信封无封泥、第二封信 | `TRACK_MISSING` | `prop_unsealed_letter.svg` 已有但未挂接 | `CONFIG_ONLY` + `ASSET_READY_UNWIRED` | 新增 `sil_messenger_on_horse_shadow.svg`；挂无封泥信封 |
| 14 | `night_knife_camp` | 营地旧案 | 无 | 深夜磨旧刀、火器刻印放火边、师父手停、见过、再问人会死 | `TRACK_MISSING` | 暂无旧刀 / 刻印 prop | `CONFIG_ONLY` + `NEEDS_ASSET` | 新增 `prop_old_master_saber.svg`、`prop_firearm_seal_mark.svg`、`sil_grinding_saber_shadow.svg` |
| 15 | `wakou_boss` | Boss 处理 | `first_act_wakou_boss` | 破船、火器箱、倭首坐箱、看岸上、军门火漆、三种处理 | `TRACK_DONE`：`wakou_boss` | `sil_wakou_boss_shadow.svg`、`prop_firearm_crate.svg` 已有但未挂接；战斗背景已强化 | `DONE_POLISH_PASS` + `ASSET_READY_UNWIRED` | 挂接倭首剪影 / 火器箱；补军门火漆焦点 |
| 16 | `military_coverup` | 终局压案 | 无 | 军门灯火、缺页案卷、朱批、木匣不见、师父站在门外 | `TRACK_DONE`：`military_coverup` | `prop_casefile_missing_page.svg` 已有但未挂接 | `TRACK_DONE` + `ASSET_READY_UNWIRED` | 挂接缺页案卷；新增 `prop_empty_wooden_case.svg`、门外师父剪影 |

---

## 5. 战斗背景矩阵

| battle_id | label | background | 对应 TSV 节点 | 当前状态 | 备注 |
|---|---|---|---|---|---|
| `prologue_master_rescue` | 黑潮救援 | `battle_bg_black_tide.svg` | `master_arrives` | `DONE_POLISH_PASS` | 已包含师父挡箭、箭线、远火村影 |
| `first_act_beach_ambush` | 海边伏击 | `battle_bg_coast_ambush.svg` | `beach_ambush` choice: 迎战 | `DONE_POLISH_PASS` | 已包含暗礁、倭影、斜向暗箭 |
| `first_act_fishing_village_embers` | 渔村残火 | `battle_bg_fishing_village_embers.svg` | `fishing_village_embers` choice: 迎战 | `DONE_POLISH_PASS` | 已包含残村、黑烟、孩子线索、村后火 |
| `first_act_transport_officer` | 押运官对峙 | `battle_bg_transport_road.svg` | `transport_officer` choice: 迎战 | `DONE_POLISH_PASS` | 已包含空车、断封条、散落军械、车辙 |
| `first_act_mutiny_camp` | 欠饷营门 | `battle_bg_mutiny_camp.svg` | `mutiny_camp` choice: 迎战 | `DONE_POLISH_PASS` | 已包含营门、低旗、空锅、饥饿士兵 |
| `first_act_wakou_boss` | 破船决战 | `battle_bg_broken_ship.svg` | `wakou_boss` | `DONE_POLISH_PASS` | 已包含破船、火器箱、倭首、岸上暗箭 |
| `test_spearman_duel` | 枪术试战 | `battle_bg_training_ground.svg` | 测试 | `DONE_POLISH_PASS` | 已有枪架、刀靶、校场木架 |
| `test_blademaster_duel` | 刀术试战 | `battle_bg_training_ground.svg` | 测试 | `DONE_POLISH_PASS` | 与枪术共用背景 |
| `fallback` | 默认接敌 | `battle_bg_training_ground.svg` | fallback | `DONE_BASE` | 可保持 |

---

## 6. 叙事资源池矩阵

### 6.1 已有 Props

| 资源 | 可服务节点 | 当前状态 | 下一步 |
|---|---|---|---|
| `assets/narrative/props/prop_casefile_missing_page.svg` | `military_coverup` | `ASSET_READY_UNWIRED` | 挂入压案演出；不再泛用于涂改军报 |
| `assets/narrative/props/prop_firearm_crate.svg` | `merchant_banquet`、`ming_firearm`、`wakou_boss` | `ASSET_READY_UNWIRED` | 挂入火器相关 track |
| `assets/narrative/props/prop_unsealed_letter.svg` | `military_messenger` | `ASSET_READY_UNWIRED` | 挂入信使 track |

### 6.2 已有 Silhouettes

| 资源 | 可服务节点 | 当前状态 | 下一步 |
|---|---|---|---|
| `assets/narrative/silhouettes/sil_master_blocks_arrow.svg` | `master_arrives` / `hidden_arrow` | `ASSET_READY_UNWIRED` | 挂入 `master_rescue` / `arrow_silence` |
| `assets/narrative/silhouettes/sil_wakou_ambusher.svg` | `beach_ambush` | `ASSET_READY_UNWIRED` | 挂入 `beach_ambush` |
| `assets/narrative/silhouettes/sil_transport_officer_shadow.svg` | `transport_officer` | `ASSET_READY_UNWIRED` | 挂入 `transport_officer` |
| `assets/narrative/silhouettes/sil_starving_soldier_shadow.svg` | `mutiny_camp` | `ASSET_READY_UNWIRED` | 挂入 `mutiny_camp` |
| `assets/narrative/silhouettes/sil_wakou_boss_shadow.svg` | `wakou_boss` | `ASSET_READY_UNWIRED` | 挂入 `wakou_boss` |

---

## 7. TSV 口径 P0 缺口

### 7.1 需要补专属 performance track

```text
beach_ambush_aftermath
fishing_village_embers
fishing_village_embers_aftermath
merchant_banquet
altered_military_report
transport_officer_aftermath
mutiny_camp
mutiny_camp_aftermath
military_messenger
night_knife_camp
```

### 7.2 需要挂接已有资源

```text
sil_master_blocks_arrow.svg
sil_wakou_ambusher.svg
sil_transport_officer_shadow.svg
sil_starving_soldier_shadow.svg
sil_wakou_boss_shadow.svg
prop_casefile_missing_page.svg
prop_firearm_crate.svg
prop_unsealed_letter.svg
```

### 7.3 需要新增的 P0 资源

```text
prop_mother_shoe_by_fire.svg
prop_wooden_training_blade.svg
prop_military_order_seal.svg
prop_coastal_patrol_map.svg
prop_official_mud_bootprint.svg
prop_burnt_bowl.svg
prop_wine_cup_key.svg
prop_firearm_seal_mark.svg
prop_altered_military_report.svg
prop_half_roster_wet.svg
prop_soaked_payroll_book.svg
prop_old_master_saber.svg
prop_empty_wooden_case.svg
sil_father_hiding_child.svg
sil_coughing_child_shadow.svg
sil_merchant_shadow.svg
sil_messenger_on_horse_shadow.svg
sil_grinding_saber_shadow.svg
```

---

## 8. 推荐下一步执行顺序

### Step 1：先补 TSV 新增线索资源

优先补：

```text
prop_firearm_seal_mark.svg
prop_half_roster_wet.svg
prop_soaked_payroll_book.svg
prop_old_master_saber.svg
prop_mother_shoe_by_fire.svg
```

原因：这些是新版 TSV 明确新增或强化的线索。

### Step 2：补 aftermath 专属 track

优先：

```text
beach_ambush_aftermath
fishing_village_embers_aftermath
transport_officer_aftermath
mutiny_camp_aftermath
```

原因：新版 TSV 已把战后处理拆成独立节点，美术不能继续只覆盖遭遇战。

### Step 3：挂接已有资源

将已有 props / silhouettes 挂入当前 track 或新增 track。

### Step 4：UI 美术化

围绕三个 TSV 变量做 UI：

```text
military_merit
clean_reputation
case_clues
```

---

## 9. 视觉一致性检查清单

每新增或替换一个节点美术资源，必须检查：

```text
1. node_id 是否对应 tables/narrative_mvp_nodes.tsv 当前实装？
2. 序章 step_id 是否对应 tables/narrative_mvp_prologue_steps.tsv 当前实装？
3. battle_id 是否来自 choices_json.combat 或 battle_scene_manifest.json？
4. performance track 是否存在，还是仍在走 fallback？
5. 是否区分遭遇节点与 aftermath 节点？
6. 是否存在一个可记忆物件？
7. 是否只留下线索，而不是直接解释阴谋？
8. SVG 是否纯本地、无字体、无外链？
9. 背景内是否没有标题文字？
10. 是否没有新增第二套背景层？
11. 是否没有把路径写死到 GDScript？
12. 是否使用 TSV 变量名：military_merit / clean_reputation / case_clues？
```
