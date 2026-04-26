# 《大明之沧海嘀鸣》节点视觉矩阵

> 版本：v0.1  
> 用途：统一 narrative node、battle_id、剧情演出、战斗背景、角色剪影和视觉记忆点。  
> 当前阶段：Phase 1，建立正式美术管线基准。

---

## 1. 状态标记

| 状态 | 含义 |
|---|---|
| `DONE_BASE` | 已有可用基础资源，能支撑 Demo 演示 |
| `NEEDS_POLISH` | 已有资源，但仍需正式化、强化细节或统一风格 |
| `NEEDS_ASSET` | 资源缺失，需要新增 |
| `CONFIG_ONLY` | 当前只有配置或文案，没有对应美术资产 |
| `LOCKED` | 已达到当前阶段标准，非必要不改 |

---

## 2. 第一幕核心节点视觉矩阵

| node_id | battle_id | 场景主题 | 视觉记忆点 | 主色调 | 战斗背景 | 剧情演出资源 | 角色 / 剪影需求 | 当前状态 | 下一步动作 |
|---|---|---|---|---|---|---|---|---|---|
| `prologue_master_rescue` | `prologue_master_rescue` | 黑潮救援 | 师父挡箭、黑潮、远处火村、主角倒地 | 黑灰、海雾灰蓝、暗朱红 | `battle_bg_black_tide.svg` | 待拆分救援演出背景 | 师父救援剪影、少年主角剪影、暗箭线 | `NEEDS_POLISH` | 增加师父挡箭动作剪影；补剧情演出 track |
| `military_order` | 无固定战斗 | 军令巡海 | 军令牌、海防图、朱砂路线、未干官印 | 宣纸米色、墨黑、暗朱红 | 无 | 需要军令 / 海防图背景 | 军门小吏剪影可选 | `CONFIG_ONLY` | 新增剧情背景与军令道具 |
| `beach_ambush` | `first_act_beach_ambush` | 海边伏击 | 低潮、暗礁、雾中倭影、斜向暗箭 | 海雾灰蓝、黑灰、米色 | `battle_bg_coast_ambush.svg` | 需对应海边伏击演出 | 倭寇伏击剪影、主角警觉剪影 | `NEEDS_POLISH` | 强化暗礁倭影和杀机线；补剧情演出 track |
| `fishing_village_embers` | `first_act_fishing_village_embers` | 渔村残火 | 残村、黑烟、火从村后起、破篱笆、孩子咳嗽 | 黑灰、烟灰、暗朱红、米色 | `battle_bg_fishing_village_embers.svg` | 需残村剧情背景 / 黑烟 / 火光 | 咳嗽孩子剪影、村民残影 | `NEEDS_POLISH` | 补剧情表演区资源；增加小物件线索 |
| `merchant_banquet` | 无固定战斗 | 雨夜海商宅 | 屏风、热酒、冷兵、屏风后火器箱 | 暗金、墨黑、暗朱红、雨灰 | 无 | 需要海商宅宴席背景 | 海商剪影、侍从剪影、屏风后箱影 | `NEEDS_ASSET` | 新增剧情背景和火器箱 prop |
| `ming_firearm` | 无固定战斗 | 明制火器 | 火器木匣、铁黑管身、官造铭痕、半遮半露 | 铁黑、暗朱红、宣纸米色 | 无 | 需要火器特写背景 / 道具 | 无或仅手部剪影 | `NEEDS_ASSET` | 新增火器箱 / 火器图纸 prop |
| `altered_military_report` | 无固定战斗 | 涂改军报 | 破庙、倒神像、军报、墨比血新 | 米色、墨黑、烟灰、暗朱红 | 无 | 需要破庙案卷背景 | 倒神像剪影、手持军报剪影 | `NEEDS_ASSET` | 新增破庙背景、军报 prop、墨迹焦点 |
| `transport_officer` | `first_act_transport_officer` | 失械案押运官 | 空车、深车辙、封条、沉默官兵 | 土黄灰、黑灰、少量暗朱红 | `battle_bg_transport_road.svg` | 需押运山道剧情演出 | 押运官剪影、沉默兵卒剪影 | `NEEDS_POLISH` | 强化封条和失械痕迹；补押运官剪影 |
| `mutiny_camp` | `first_act_mutiny_camp` | 欠饷营门 | 营门、低垂军旗、空粮袋、破枪、空锅 | 土黄灰、黑灰、暗红旗 | `battle_bg_mutiny_camp.svg` | 需欠饷营剧情演出 | 饥饿士兵剪影、磨刀士卒剪影 | `NEEDS_POLISH` | 增加空锅 / 瘦兵剪影；补剧情演出 track |
| `military_messenger` | 无固定战斗 | 军门信使 | 雨中信使、马喘、无封泥信封、泥水 | 冷蓝灰、黑灰、米色 | 无 | 需要雨夜路边背景 | 信使骑马剪影、无封泥信封特写 | `NEEDS_ASSET` | 新增信使剧情背景和信封 prop |
| `night_knife_camp` | 无固定战斗 | 夜半磨刀 | 深夜营火、磨刀声、师父旧刀、低声兵语 | 黑灰、暗朱红、铁黑 | 无 | 需要深夜营地背景 | 师父旧刀特写、磨刀士卒剪影 | `NEEDS_ASSET` | 新增营地夜景 / 旧刀 prop |
| `wakou_boss` | `first_act_wakou_boss` | 破船决战 | 破船、火器箱、岸上暗箭、背光倭寇首领 | 海雾灰蓝、黑灰、暗朱红 | `battle_bg_broken_ship.svg` | 需破船决战演出 | 倭寇首领剪影、暗箭剪影、火器箱 | `NEEDS_POLISH` | 强化 Boss 压迫构图；新增首领剪影 |
| `military_coverup` | 无固定战斗 | 军门压案 | 军门灯火、缺页案卷、官泥、空木匣 | 墨黑、米色、暗金、暗朱红 | 无 | 需要军门案房背景 | 军门官员剪影、翻案卷手部剪影 | `NEEDS_ASSET` | 新增案房背景、缺页案卷、官泥 prop |

---

## 3. 测试 / 备用场景矩阵

| battle_id | 场景主题 | 当前资源 | 当前状态 | 下一步动作 |
|---|---|---|---|---|
| `test_spearman_duel` | 枪术试战 | `battle_bg_training_ground.svg` | `NEEDS_POLISH` | 增加枪架、靶桩、校场纵深 |
| `test_blademaster_duel` | 刀术试战 | `battle_bg_training_ground.svg` | `NEEDS_POLISH` | 与枪术共用校场背景，后续可用不同前景道具区分 |
| `fallback` | 默认接敌 | `battle_bg_training_ground.svg` | `DONE_BASE` | 保持可用即可，非 P0 |

---

## 4. 视觉一致性检查清单

每新增或替换一个节点美术资源，必须检查：

```text
1. node_id 是否有明确场景主题？
2. battle_id 是否使用同一视觉意象？
3. 剧情背景和战斗背景是否共享色调？
4. 是否存在一个可记忆物件？
5. 是否只留下线索，而不是直接解释阴谋？
6. 是否避开了战斗角色和格位区域？
7. SVG 是否纯本地、无字体、无外链？
8. 背景内是否没有标题文字？
9. 是否没有新增第二套背景层？
10. 是否没有把路径写死到 GDScript？
```

---

## 5. Phase 2 推荐执行顺序

### P0：战斗背景二次强化

优先让所有第一幕战斗背景达到“正式分镜”水平：

```text
1. battle_bg_black_tide.svg
2. battle_bg_coast_ambush.svg
3. battle_bg_fishing_village_embers.svg
4. battle_bg_transport_road.svg
5. battle_bg_mutiny_camp.svg
6. battle_bg_broken_ship.svg
7. battle_bg_training_ground.svg
```

每张背景强化重点：

| 资源 | 强化重点 |
|---|---|
| `battle_bg_black_tide.svg` | 加师父挡箭剪影、箭线、远火村影 |
| `battle_bg_coast_ambush.svg` | 加暗礁倭影、斜向杀机线、低潮层次 |
| `battle_bg_fishing_village_embers.svg` | 加残屋细节、孩子相关小物件、黑烟方向 |
| `battle_bg_transport_road.svg` | 加封条、散落军械、深车辙 |
| `battle_bg_mutiny_camp.svg` | 加空锅、瘦兵剪影、破枪密度 |
| `battle_bg_broken_ship.svg` | 加倭寇首领背影、火器箱焦点、岸上暗箭 |
| `battle_bg_training_ground.svg` | 加枪架、刀靶、校场木桩、军旗远影 |

### P1：剧情演出资源

优先补这些 node 的剧情表演区资源：

```text
fishing_village_embers
merchant_banquet
altered_military_report
mutiny_camp
military_messenger
night_knife_camp
military_coverup
```

### P2：角色剪影

优先角色：

```text
主角青年武官
师父 / 退伍老兵
小股倭寇首领
押运官
军门信使
海商
```

---

## 6. 当前 P0 缺口汇总

| 类型 | 缺口 |
|---|---|
| 战斗背景 | 已有基础资源，但多张仍需“正式分镜级”二次强化 |
| 剧情演出 | 多数核心剧情节点缺少独立背景 / prop / silhouette |
| 角色剪影 | 主角、师父、倭寇首领、押运官、信使、海商仍缺 |
| UI 美术 | 案卷、军令、兵书、封泥体系尚未正式落地 |
| 主视觉 | 标题字、key art、对外截图尚未启动 |

---

## 7. 资源命名建议

### 战斗背景

```text
assets/pixel_battle/backgrounds/battle_bg_<scene_name>.svg
```

### 剧情背景

```text
assets/narrative/backgrounds/bg_<node_id>.svg
```

### 叙事道具

```text
assets/narrative/props/prop_<object_name>.svg
```

### 人物剪影

```text
assets/narrative/silhouettes/sil_<role_or_action>.svg
```

---

## 8. 管线原则

后续所有美术替换优先遵循：

```text
先查 NODE_VISUAL_MATRIX
再查 ART_DIRECTION_GUIDE
再新增 / 替换资源
最后只通过 manifest 或 performance_tracks 挂接
```

禁止直接在 GDScript 内硬编码新资源路径。
