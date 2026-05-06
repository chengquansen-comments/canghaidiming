# AI / Godot 排障规则归档

当前排障规则已并入 [ENGINEERING.md](ENGINEERING.md) 的“Godot 排障规则”小节。

保留结论：

- 不要只相信 Godot 表层继承报错路径。
- 先完整展开 `extends` 链，再定位第一个真实 parser / warning / runtime error。
- 必要时运行 `tools/debug_mainvisual_load_chain.gd`。
- 不要为绕过错误随意更换 scene 挂载脚本、复制临时 controller 或新增 stable entry。
- 先定位真实根因，再做最小补丁。

后续排障流程直接维护 [ENGINEERING.md](ENGINEERING.md)。
