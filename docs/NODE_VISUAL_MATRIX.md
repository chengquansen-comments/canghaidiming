# 《大明之沧海嘀鸣》节点视觉矩阵

> 版本：v0.2  
> 对齐分支：`main`  
> 对齐依据：`data/narrative_mvp_nodes.json` v2、`data/battle_scene_manifest.json`、`data/performance_tracks.json`  
> 用途：统一 narrative node、battle_id、剧情演出 track、战斗背景、叙事道具和角色剪影状态。

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
| `CONFIG_ONLY` | 当前只有剧情配置或文案，没有对应美术资产 |
| `LOCKED` | 当前阶段不建议继续改，除非发现明显问题 |

---

## 2. 当前已实装剧情结构

### 2.1 序章十二拍

| step_id | 视觉主题 | 演出状态 | 关键资源 / 缺口 | 下一步 |
|---|---|---|---|---|
| `black_tide` | 黑潮、近潮声、奔跑 | `TRACK_DONE`：`black_tide_0` | 黑潮背景已存在 | 可保持 |
| `father` | 父亲把主角按进柴堆 | `TRACK_DONE`：`black_tide_1` | 缺父亲 / 柴堆剪影 | P1 补剪影 |
| `door` | 刀背敲门、东西在哪 | `TRACK_DONE`：`black_tide_2` | 缺门影 / 刀背敲门 prop | P1 补 |
| `dead` | 父母遇害、潮声停顿 | `TRACK_DONE`：`black_tide_3` | 缺母亲鞋 / 火光近景 prop | P1 补 |
| `wooden_blade` | 木刀打在甲片上 | `TRACK_DONE`：复用黑潮段 | 缺木刀 prop | P1 补 |
| `fall` | 天翻、火高、母亲的鞋 | `TRACK_DONE`：复用黑潮段 | 缺母亲鞋 prop | P1 补 |
| `master_arrives` | 师父挡眼、换我、接敌 | `TRACK_DONE`：`master_rescue` | `sil_master_blocks_arrow.svg` 已有但未挂接 | 挂入演出配置 |
| `three_cards` | 刀、步、断气 | `TRACK_DONE`：复用战斗后节奏 | 可用抽象卡牌 / 刀谱 | P2 |
| `military_word` | 敌人口吐“军” | `TRACK_DONE`：`arrow_silence` | 缺口吐字 / 断句焦点 | P2 |
| `hidden_arrow` | 箭从黑处来，不是海上 | `TRACK_DONE`：`arrow_silence` | 箭线已在战斗背景中强化 | 可保持 |
| `dont_look` | 师父说别看 | `TRACK_DONE`：`arrow_silence` | 师父遮眼剪影待补 | P1 |
| `departure` | 十年后出山，师父还刀 | `TRACK_DONE`：`departure` | 缺师父旧刀 prop | P0 补 |

---

## 3. 第一幕节点视觉矩阵

| node_id | battle_id | 当前剧情实装视觉 | 战斗背景 | performance track | 已有 props / silhouettes | 当前状态 | 下一步动作 |
|---|---|---|---|---|---|---|---|
| `military_order` | 无 | 军门外、天未亮、旗湿、军令压案、墨未干、旧案不得声张 | 无战斗 | `TRACK_DONE`：`military_order` | 暂无军令牌 / 海防图 prop | `CONFIG_ONLY` + `TRACK_DONE` | 新增 `prop_military_order_seal.svg`、`prop_coastal_patrol_map.svg` |
| `beach_ambush` | `first_act_beach_ambush` | 沙滩脚印整齐、官泥、芦苇里枪尖 | `battle_bg_coast_ambush.svg` | `TRACK_DONE`：`beach_ambush` | `sil_wakou_ambusher.svg` 已有但未挂接 | `DONE_POLISH_PASS` + `ASSET_READY_UNWIRED` | 挂接伏击剪影；可补官泥脚印 prop |
| `fishing_village_embers` | `first_act_fishing_village_embers` | 残村、黑烟、孩子咳嗽、火不是从海边烧起 | `battle_bg_fishing_village_embers.svg` | `TRACK_MISSING` | 背景内已有孩子线索，但无独立 prop / silhouette | `DONE_POLISH_PASS` + `TRACK_MISSING` | 新增专属 track；补 `sil_coughing_child_shadow.svg` 或 `prop_burnt_bowl.svg` |
| `merchant_banquet` | 无 | 雨夜海商宅、热酒、冷兵、屏风后火器箱、箱钥匙在酒盏旁 | 无战斗 | `TRACK_MISSING` | `prop_firearm_crate.svg` 已有但未挂接 | `CONFIG_ONLY` + `ASSET_READY_UNWIRED` | 新增宴席背景、海商剪影、屏风 / 酒盏钥匙 prop |
| `ming_firearm` | 无 | 倭船舱、木箱半开、明制火器、官造二字 | 无战斗 | `TRACK_DONE`：`ming_firearm` | `prop_firearm_crate.svg` 已有但未挂接 | `TRACK_DONE` + `ASSET_READY_UNWIRED` | 将火器箱 prop 设为 focus；补官造铭痕细节 |
| `altered_military_report` | 无 | 破庙、倒神像、香炉下军报、死者人数被涂、墨比血新 | 无战斗 | `TRACK_MISSING` | `prop_casefile_missing_page.svg` 可部分复用，但缺军报/破庙资源 | `CONFIG_ONLY` + `TRACK_MISSING` | 新增破庙背景、`prop_altered_military_report.svg`、倒神像剪影 |
| `transport_officer` | `first_act_transport_officer` | 山道、空车、深车辙、押运名册、木匣不见 | `battle_bg_transport_road.svg` | `TRACK_DONE`：`transport_officer` | `sil_transport_officer_shadow.svg` 已有但未挂接 | `DONE_POLISH_PASS` + `ASSET_READY_UNWIRED` | 挂接押运官剪影；补半页名册 prop |
| `mutiny_camp` | `first_act_mutiny_camp` | 营门、军旗、无粮、欠饷、不是倭寇也挡路 | `battle_bg_mutiny_camp.svg` | `TRACK_MISSING` | `sil_starving_soldier_shadow.svg` 已有但未挂接 | `DONE_POLISH_PASS` + `TRACK_MISSING` | 新增专属 track；挂饥饿士兵剪影 / 空锅 focus |
| `military_messenger` | 无 | 雨中信使、马比人先喘、信封没有封泥、第二封信 | 无战斗 | `TRACK_MISSING` | `prop_unsealed_letter.svg` 已有但未挂接 | `CONFIG_ONLY` + `ASSET_READY_UNWIRED` | 新增雨中信使 track；补骑马信使剪影 |
| `night_knife_camp` | 无 | 营地深夜、雨停、刀声没停、师父磨旧刀、令迟了 | 无战斗 | `TRACK_MISSING` | 暂无师父旧刀 prop | `CONFIG_ONLY` + `NEEDS_ASSET` | 新增 `prop_old_master_saber.svg`、磨刀剪影、专属 track |
| `wakou_boss` | `first_act_wakou_boss` | 破船、火器箱、倭首坐箱、你找错海、看岸不看海、箭声又响 | `battle_bg_broken_ship.svg` | `TRACK_DONE`：`wakou_boss` | `sil_wakou_boss_shadow.svg`、`prop_firearm_crate.svg` 已有但未挂接 | `DONE_POLISH_PASS` + `ASSET_READY_UNWIRED` | 挂接倭首剪影 / 火器箱 focus；补岸上暗箭 beat |
| `military_coverup` | 无 | 军门灯火、案卷缺页、朱批、木匣不见、倭患已平 | 无战斗 | `TRACK_DONE`：`military_coverup` | `prop_casefile_missing_page.svg` 已有但未挂接 | `TRACK_DONE` + `ASSET_READY_UNWIRED` | 挂接缺页案卷 prop；补官泥 / 空木匣 prop |

---

## 4. 战斗背景矩阵

| battle_id | label | background | 对应节点 | 当前状态 | 备注 |
|---|---|---|---|---|---|
| `prologue_master_rescue` | 黑潮救援 | `battle_bg_black_tide.svg` | 序章 `master_arrives` | `DONE_POLISH_PASS` | 已包含师父挡箭、箭线、远火村影 |
| `first_act_beach_ambush` | 海边伏击 | `battle_bg_coast_ambush.svg` | `beach_ambush` | `DONE_POLISH_PASS` | 已包含暗礁、倭影、斜向暗箭 |
| `first_act_fishing_village_embers` | 渔村残火 | `battle_bg_fishing_village_embers.svg` | `fishing_village_embers` | `DONE_POLISH_PASS` | 已包含残村、黑烟、孩子线索、村后火 |
| `first_act_transport_officer` | 押运官对峙 | `battle_bg_transport_road.svg` | `transport_officer` | `DONE_POLISH_PASS` | 已包含空车、断封条、散落军械、车辙 |
| `first_act_mutiny_camp` | 欠饷营门 | `battle_bg_mutiny_camp.svg` | `mutiny_camp` | `DONE_POLISH_PASS` | 已包含营门、低旗、空锅、饥饿士兵 |
| `first_act_wakou_boss` | 破船决战 | `battle_bg_broken_ship.svg` | `wakou_boss` | `DONE_POLISH_PASS` | 已包含破船、火器箱、倭首、岸上暗箭 |
| `test_spearman_duel` | 枪术试战 | `battle_bg_training_ground.svg` | 测试 | `DONE_POLISH_PASS` | 已有枪架、刀靶、校场木架 |
| `test_blademaster_duel` | 刀术试战 | `battle_bg_training_ground.svg` | 测试 | `DONE_POLISH_PASS` | 与枪术共用背景 |
| `fallback` | 默认接敌 | `battle_bg_training_ground.svg` | fallback | `DONE_BASE` | 可保持 |

---

## 5. 叙事资源池矩阵

### 5.1 Props

| 资源 | 对应节点 | 当前状态 | 下一步 |
|---|---|---|---|
| `assets/narrative/props/prop_casefile_missing_page.svg` | `military_coverup`，可部分支持 `altered_military_report` | `ASSET_READY_UNWIRED` | 挂入压案演出；另补涂改军报专用 prop |
| `assets/narrative/props/prop_firearm_crate.svg` | `merchant_banquet`、`ming_firearm`、`wakou_boss` | `ASSET_READY_UNWIRED` | 挂入火器相关 track |
| `assets/narrative/props/prop_unsealed_letter.svg` | `military_messenger` | `ASSET_READY_UNWIRED` | 挂入信使 track |

### 5.2 Silhouettes

| 资源 | 对应节点 | 当前状态 | 下一步 |
|---|---|---|---|
| `assets/narrative/silhouettes/sil_master_blocks_arrow.svg` | 序章 `master_arrives` / `hidden_arrow` | `ASSET_READY_UNWIRED` | 挂入 `master_rescue` / `arrow_silence` |
| `assets/narrative/silhouettes/sil_wakou_ambusher.svg` | `beach_ambush` | `ASSET_READY_UNWIRED` | 挂入 `beach_ambush` |
| `assets/narrative/silhouettes/sil_transport_officer_shadow.svg` | `transport_officer` | `ASSET_READY_UNWIRED` | 挂入 `transport_officer` |
| `assets/narrative/silhouettes/sil_starving_soldier_shadow.svg` | `mutiny_camp` | `ASSET_READY_UNWIRED` | 挂入 `mutiny_camp` |
| `assets/narrative/silhouettes/sil_wakou_boss_shadow.svg` | `wakou_boss` | `ASSET_READY_UNWIRED` | 挂入 `wakou_boss` |

---

## 6. 当前 P0 缺口

### 6.1 需要补专属 performance track

```text
fishing_village_embers
merchant_banquet
altered_military_report
mutiny_camp
military_messenger
night_knife_camp
```

### 6.2 需要挂接已有资源

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

### 6.3 需要新增的 P0 资源

```text
prop_military_order_seal.svg
prop_coastal_patrol_map.svg
prop_altered_military_report.svg
prop_old_master_saber.svg
prop_empty_wooden_case.svg
sil_coughing_child_shadow.svg
sil_merchant_shadow.svg
sil_messenger_on_horse_shadow.svg
sil_grinding_saber_shadow.svg
```

---

## 7. 推荐下一步执行顺序

### Step 1：先挂接已有资源

目标：不再让资源池闲置。

```text
1. 在 performance_tracks.json 中为可支持的 track 增加 prop / silhouette 引用字段。
2. 将 master / wakou / officer / soldier / boss 剪影挂入对应节点。
3. 将 casefile / firearm_crate / unsealed_letter 挂入对应节点。
```

### Step 2：补 6 个缺失专属 track

```text
fishing_village_embers
merchant_banquet
altered_military_report
mutiny_camp
military_messenger
night_knife_camp
```

### Step 3：补缺失资源

优先：

```text
prop_old_master_saber.svg
prop_altered_military_report.svg
sil_messenger_on_horse_shadow.svg
sil_merchant_shadow.svg
```

### Step 4：UI 美术化

围绕三个实装变量做 UI：

```text
jun_gong
qing_wang
clues
```

---

## 8. 视觉一致性检查清单

每新增或替换一个节点美术资源，必须检查：

```text
1. node_id 是否对应 narrative_mvp_nodes.json 当前实装？
2. battle_id 是否对应 battle_scene_manifest.json 当前实装？
3. performance track 是否存在，还是仍在走 fallback？
4. 剧情背景和战斗背景是否共享色调？
5. 是否存在一个可记忆物件？
6. 是否只留下线索，而不是直接解释阴谋？
7. SVG 是否纯本地、无字体、无外链？
8. 背景内是否没有标题文字？
9. 是否没有新增第二套背景层？
10. 是否没有把路径写死到 GDScript？
```
