# ChatGPT 排 Bug 准则

> 适用于本项目中由 ChatGPT / Codex / AI 助手参与的 Godot、GDScript、剧情链路、战斗链路排障。
>
> 核心原则：先定位真实根因，再做最小补丁。不要根据表层报错盲目改链路、绕过系统或新增临时脚本。

---

## 1. 不要只相信 Godot 表层报错路径

Godot 常见报错：

```text
Could not resolve super class inheritance from "res://scripts/xxx.gd"
```

不能直接理解为：

```text
xxx.gd 文件不存在，或 xxx.gd 本身一定是根因。
```

更准确的理解是：

```text
Godot 在加载这条继承链时失败了。
```

真实错误可能在：

```text
当前脚本
父类脚本
父类的父类脚本
更深祖先脚本
祖先脚本 preload 的 class_name 脚本
祖先脚本中的缩进 / 语法 / 类型 warning-as-error
```

因此，看到继承解析错误时，第一反应应该是：**完整展开继承链，找第一个真正不能解析的脚本**。

---

## 2. 必须先完整展开 extends 链

排 Godot 继承错误时，先画出完整链路，例如：

```text
MainVisual.tscn
  -> battle_controller_visual_story_return_intent_visibility.gd
    -> battle_controller_visual_story_return.gd
      -> battle_controller_visual_settlement_mode.gd
        -> battle_controller_visual_preview_position_guard.gd
          -> battle_controller_visual_presentation_mode_aware.gd
            -> battle_controller_visual_presentation_stepwise.gd
              -> battle_controller_visual_presentation.gd
                -> battle_controller_visual_scene_manifest.gd
                  -> battle_controller_visual_narrative_formal.gd
                    -> battle_controller_visual_narrative_context.gd
                      -> battle_controller_visual_break_preview.gd
                        -> battle_controller_visual_resolver_preview.gd
```

判断标准不是：

```text
报错里出现了哪个父类名。
```

而是：

```text
整条链路里，哪一个脚本最先 parse / load 失败。
```

---

## 3. 优先跑 headless 校验，不要静态猜

如果环境允许，优先运行：

```bash
HOME=/private/tmp godot --headless --path . --quit scenes/MainVisual.tscn
HOME=/private/tmp godot --headless --quit --path .
git diff --check
```

说明：

```text
HOME=/private/tmp
```

是为了避免 Godot 在 sandbox / 受限环境下写 `user://logs` 失败，导致 logger 初始化异常盖住真正脚本错误。

如果 headless 能直接暴露具体文件和行号，以 headless 输出为准。

---

## 4. 必要时逐层 load 继承链

如果 Godot 仍只报外层继承失败，可以写一个临时检查脚本或用最小加载方式逐层验证：

```gdscript
load("res://scripts/battle_controller_visual_story_return_intent_visibility.gd")
load("res://scripts/battle_controller_visual_story_return.gd")
load("res://scripts/battle_controller_visual_settlement_mode.gd")
load("res://scripts/battle_controller_visual_preview_position_guard.gd")
load("res://scripts/battle_controller_visual_presentation_mode_aware.gd")
load("res://scripts/battle_controller_visual_presentation_stepwise.gd")
load("res://scripts/battle_controller_visual_presentation.gd")
load("res://scripts/battle_controller_visual_scene_manifest.gd")
load("res://scripts/battle_controller_visual_narrative_formal.gd")
load("res://scripts/battle_controller_visual_narrative_context.gd")
load("res://scripts/battle_controller_visual_break_preview.gd")
load("res://scripts/battle_controller_visual_resolver_preview.gd")
```

目标：

```text
找到第一个不能 load 的脚本。
```

而不是盯住最外层报错中的父类路径。

---

## 5. 项目内继承链诊断脚本

本项目保留了一个专用诊断脚本：

```text
tools/debug_mainvisual_load_chain.gd
```

使用命令：

```bash
HOME=/private/tmp godot --headless --path . --script tools/debug_mainvisual_load_chain.gd
```

它会从 `res://scripts/battle_controller_visual_story_return_intent_visibility.gd` 开始，读取真实 `extends "..."` 链路，打印：

```text
=== Extends chain child -> parent ===
CHAIN[00]: ...
CHAIN[01]: ...
```

然后按“最深父类 -> 子类 -> MainVisual.tscn”的顺序逐层 `load()`：

```text
=== Load chain parent -> child ===
LOAD_BEGIN: ...
LOAD_OK: ...
LOAD_FAILED: ...
```

排查原则：

```text
1. 第一条真实 SCRIPT ERROR / Parse Error 才是根因候选。
2. 后续一连串 Could not resolve class 通常只是祖先失败后的冒泡结果。
3. 不要因为最后报 story_return / settlement / MainVisual 就直接改这些外层文件。
4. 只修第一处真实 parser error 所在文件。
```

典型案例：

```text
外层表现：
Could not resolve class "res://scripts/battle_controller_visual_story_return.gd"

真实根因：
scripts/battle_controller_visual_presentation_stepwise_exchange.gd 中，把返回 void 的 coroutine 当成返回值保存。
```

修复前必须先跑这个脚本或同等逐层 load 工具，避免盲目改继承链。

---

## 6. 区分 Parser Error、Warning-as-error、Runtime Error

不要把所有 Godot 报错都归因到 `Variant` 类型推断。

需要先判断错误类型：

```text
Parser Error
  语法错误、缩进错误、继承解析失败、class_name / preload 失败。

Warning treated as error
  Variant 推断、unsafe assignment、未使用变量等 warning 被项目设置为 error。

Runtime Error
  运行时空指针、函数不存在、状态不一致、资源缺失。
```

`Variant inferred as Variant` 是常见问题，但不是所有继承失败的根因。

---

## 7. 不要轻易改链路、绕过、加文件

继承链报错时，禁止优先采用这些做法：

```text
修改 MainVisual.tscn 挂载脚本
绕过 story_return / settlement_mode / presentation 层
新增 stable entry / temporary entry 脚本
降低父类层级
复制一份临时控制器
```

这些操作会改变系统结构，容易把战斗流程、剧情返回、UI 结算、意图预览改乱。

正确做法：

```text
只修第一个真实 parser error
不改场景挂载
不改 extends 链
不新增临时脚本
不改变战斗流程
```

除非已经明确证明架构链路本身就是设计错误。

---

## 8. 每次改动前先声明补丁边界

在动代码前，必须先明确：

```text
本次只改哪个文件
不改哪些文件
不改哪些逻辑
验证命令是什么
预期结果是什么
```

示例：

```text
只改 scripts/battle_controller_visual_resolver_preview.gd 第 373 行缩进。
不改 MainVisual.tscn。
不改 battle_controller_visual_story_return.gd。
不改战斗结算逻辑。
验证：godot --headless 加载 MainVisual.tscn。
```

---

## 9. Godot 继承错误标准排查流程

按以下顺序执行：

```text
1. 记录完整报错原文，包括文件、行号、场景。
2. 确认目标文件是否存在。
3. 查场景挂载脚本。
4. 完整展开 extends 链。
5. 跑 headless 加载目标场景。
6. 如仍不清晰，逐层 load 继承链；MainVisual 优先用 tools/debug_mainvisual_load_chain.gd。
7. 找到第一个真实 parser error。
8. 只修这个点。
9. 运行 git diff --check。
10. 再跑 headless 验证。
11. 验证通过后再提交。
```

---

## 10. Godot warning-as-error 常见修法

如果确认是 `Variant` 推断 warning，优先使用显式类型或显式转换。

### Dictionary.get

不推荐：

```gdscript
var encounter: Dictionary = data.get("encounter", {})
```

推荐：

```gdscript
var encounter: Dictionary = data.get("encounter", {}) as Dictionary
```

更安全：

```gdscript
var encounter_value: Variant = data.get("encounter", {})
var encounter: Dictionary = {}
if encounter_value is Dictionary:
    encounter = encounter_value as Dictionary
```

### max / min

不推荐：

```gdscript
var width := max(1.0, view_size.x - 20.0)
```

推荐：

```gdscript
var width: float = maxf(1.0, view_size.x - 20.0)
```

整数用：

```gdscript
var value: int = maxi(0, current_value)
```

### get_children

不推荐：

```gdscript
for child in container.get_children():
    child.queue_free()
```

推荐：

```gdscript
for child: Node in container.get_children():
    child.queue_free()
```

### slice 返回值

不推荐：

```gdscript
return pool.slice(0, count)
```

推荐：

```gdscript
var selected: Array[CardData] = []
var selected_count: int = mini(count, pool.size())
for i in range(selected_count):
    selected.append(pool[i])
return selected
```

---

## 11. 缩进 / 语法错误优先级高于类型 warning

如果出现 Parser Error，必须优先检查：

```text
缩进是否多一层 / 少一层
if / elif / else 是否对齐
match 分支是否对齐
函数体是否意外嵌套
lambda / connect 里的缩进是否闭合
```

这类错误可能导致祖先脚本完全 parse 失败，Godot 最外层只显示继承失败。

典型现象：

```text
外层报：Could not resolve super class inheritance from xxx.gd
真实根因：更深祖先脚本某一行缩进错误
```

---

## 12. 提交前必须说明验证结果

提交说明至少包含：

```text
修了哪个真实根因
改了哪些文件
没有动哪些链路
执行了哪些验证
验证结果是什么
```

示例：

```text
修复 battle_controller_visual_resolver_preview.gd 第 373 行缩进错误。
未修改 MainVisual.tscn、story_return 继承链和战斗流程。
验证：
- HOME=/private/tmp godot --headless --path . --quit scenes/MainVisual.tscn
- HOME=/private/tmp godot --headless --quit --path .
- git diff --check
结果：通过。
```

---

## 13. 一句话原则

> Godot 的继承错误是“链路加载失败”，不是“报错里那个父类一定错”。先跑验证，沿继承链找第一个真实 parse error，再做最小补丁。
