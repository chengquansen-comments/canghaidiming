# 重构待办归档

当前重构优先级已并入 [ENGINEERING.md](ENGINEERING.md) 的“当前重构优先级”小节。

保留当前 P0：

- `scripts/compile_tables.py`：拆 loader / validator / writer。
- `tools/render_art_prompt.py`：拆 loader / renderer / cli。

保留当前 P1：

- `scripts/narrative/narrative_demo_controller.gd`。
- `scripts/narrative_battle_context.gd`。
- `scripts/battle_controller_visual_resolver_preview.gd`。
- `scripts/narrative_demo_safe_controller.gd`。

后续重构排期直接维护 [ENGINEERING.md](ENGINEERING.md)，不要恢复长流水账。
