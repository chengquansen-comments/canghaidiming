# 《大明之沧海嘀鸣》Godot 4 单局 Demo

这是根据 `/Users/happy/Downloads/《大明之沧海嘀鸣》单局设计方案.pdf` 落地的一个 Godot 4 可运行原型，范围按文档第 15 节 MVP 收敛。

## 已实现内容

- 2 个开局模板
  - `戚家军枪手`：优势距离 `2-3`，强调压势与打断
  - `单刀快手`：优势距离 `1-2`，强调连压与爆发
- 3 个核心资源
  - `血`
  - `势`
  - `距离（0-3）`
- 4 类核心卡牌
  - `步法`
  - `架势`
  - `攻击`
  - `杀招`
- 6 场连续战斗
  - 普通敌人 3 个
  - 精英 2 个
  - Boss 1 个
- 1 张带分支的单局路线图
  - `遭遇战`
  - `校场`
  - `行营`
  - `军令`
- 3 个关键验证点
  - `削敌势打断招式`
  - `完美格挡吸势`
  - `崩塌后处决`

## 运行方式

如果本机 `godot` 已在 PATH 中：

```bash
cd /Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf
godot --path .
```

如果你更习惯编辑器，也可以直接用 Godot 4 打开这个目录。

## 项目结构

- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/project.godot`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scenes/Main.tscn`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/Main.gd`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/data/classes.json`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/data/cards.json`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/data/effects.json`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/data/enemies.json`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/data/routes.json`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/data/rewards.json`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/tables/*.tsv`
- `/Users/happy/Documents/Codex/2026-04-19-files-mentioned-by-the-user-pdf/scripts/compile_tables.py`

## 数据驱动说明

- `classes.json`：开局模板、武器、优势距离、初始牌组
- `cards.json`：卡牌文字、费用、类别、效果列表
- `effects.json`：效果类型注册表，定义处理器名、必填字段、效果说明
- `enemies.json`：敌人基础属性、优势距离、意图序列
- `routes.json`：路线节点、分支连接、地图长度、初始距离
- `rewards.json`：战后可进入奖励池的卡牌 id

当前主脚本会在启动时自动加载并校验这些 JSON：

- 文件不存在会直接报错
- JSON 格式错误会直接报错
- 模板/奖励池引用不存在卡牌会直接报错
- 卡牌引用未注册效果类型会直接报错
- 效果类型缺少处理器或必填字段会直接报错
- 敌人缺少关键字段或没有意图会直接报错

## TSV 配表流程

`tables/*.tsv` 是唯一策划入口。不要直接编辑 `data/*.json`；运行编译器后 JSON 会被 TSV 覆盖生成。

主要源表：

- `tables/classes.tsv`：开局模板
- `tables/cards.tsv`：卡牌基础信息
- `tables/card_effects.tsv`：卡牌效果明细，一行一个效果
- `tables/effect_types.tsv`：效果类型注册表
- `tables/enemies.tsv`：敌人基础属性
- `tables/enemy_intents.tsv`：敌人招式意图，一行一个意图
- `tables/routes.tsv`：路线节点、下一跳、地图长度、初始距离
- `tables/rewards.tsv`：奖励池
- `tables/battle_scene_manifest.tsv`：战斗 battle_id、背景、镜头参数
- `tables/enemy_manifest_*.tsv`：剧情战斗 encounter、敌人数值、牌组、AI 权重、阶段行为、奖励
- `tables/narrative_mvp_*.tsv`：MVP 剧情节点、序章、选项、战斗触发、结局提示
- `tables/performance_*.tsv`：剧情演出 timeline 与 beats
- `tables/raw_json_documents.tsv`：暂未拆表的大型叙事文档，由 TSV 原样生成到 `data/narrative/*.json`

编译命令：

```bash
cd /Users/happy/Documents/Codex/canghaidiming
python3 scripts/compile_tables.py
```

编译完成后会自动覆盖生成：

- `data/classes.json`
- `data/cards.json`
- `data/effects.json`
- `data/enemies.json`
- `data/routes.json`
- `data/rewards.json`
- `data/battle_scene_manifest.json`
- `data/enemy_manifest.json`
- `data/narrative_mvp_nodes.json`
- `data/performance_tracks.json`
- `data/narrative/mvp_compressed_narrative.json`
- `data/narrative/mvp_static_map_layout.json`

### 表格字段约定

- 多值字段统一用 `|` 分隔：
  - 例如 `preferred_ranges` 写成 `2|3`
  - 例如 `tags` 写成 `突进|流血`
  - 例如 `deck` 写成 `mid_spear|mid_spear|guard_frame`
- 布尔字段用 `true / false`
- `card_effects.tsv` 与 `enemy_intents.tsv` 的 `order` 用来决定执行顺序
- 每条卡牌效果、每条敌人意图都单独占一行，这样更适合在表格里筛选、排序和批量编辑

### TSV 规则

- 提交策划改动时应提交 `tables/*.tsv` 和由编译器生成的对应 `data/*.json`
- 如果 JSON 和 TSV 不一致，以 TSV 为准，重新运行 `python3 scripts/compile_tables.py`
- 编译器仍兼容历史 `.csv` fallback，但项目内规范只使用 TSV，避免双入口混淆

## 扩展效果类型

现在新增一个效果类型的最小步骤是：

1. 在 `tables/effect_types.tsv` 注册新类型，声明 `handler` 和 `required_fields`
2. 在 `scripts/Main.gd` 中实现对应处理函数
3. 在 `tables/card_effects.tsv` 里把该效果写进某张卡牌的 `effects`
4. 运行 `python3 scripts/compile_tables.py` 生成 JSON

这意味着“效果类型目录”和“卡牌使用效果”的结构已经解耦；脚本不再直接硬编码支持哪些效果类型，而是先读取注册表再分发执行。

## 当前 demo 的设计取舍

- 地图层现在已经改成简化分支路线，但仍是固定模板，不是随机生成。
- `校场 / 行营 / 军令` 已有基础节点功能，但事件文本与后果还比较简化。
- `完美格挡` 采用文档建议：完全挡住伤害且超额格挡不超过 3 时触发吸势。
- `崩塌` 的处理为：
  - 本回合动作取消
  - 下次受击必暴击
  - 为 `崩枪 / 拖刀杀 / 斩首` 提供处决窗口

## 建议下一步

如果继续扩成正式原型，优先补下面三块：

1. `路线图层`
2. `事件/器械所/兵书房`
3. `数据驱动卡牌与敌人配置`
