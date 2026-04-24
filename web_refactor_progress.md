# Web 重构进度（持续更新）

## 当前阶段：Milestone D（结构收口 + Web 验证）

---

## 本轮刷新结论

本轮不再继续补工具链，也不再做零散小修，已进入“大步子结构收口”：

- cached visual controller 不再继续承载角色显示配置细节。
- 角色裁帧、显示边界、脚底锚点、动画落点已下沉到独立 Actor helper。
- 当前 visual 分层已经形成：Stage / HUD / Skin / Actor / Cached Controller。

---

## 已完成（Web 基线）

- [x] compatibility renderer 切换
- [x] Web export preset（单线程）
- [x] Web shell + 本地预览链路
- [x] Web bundle 构建 / 校验 / manifest / checksum / smoke test
- [x] Web CJK 字体方案：项目内嵌字体路径 + 本地字体安装脚本

---

## 已完成（Visual 架构）

### Helper 分层

- [x] BattleStageHelper
  - grid 几何缓存
  - grid slot 状态构造
  - range overlay 样式配置
  - 预览位移 / 攻击范围 / 动画落点辅助

- [x] BattleHudHelper
  - 卡牌摘要文本缓存
  - 按钮文本缓存
  - 卡牌详情文本缓存
  - intent bubble 文案
  - effect preview 文案
  - effect preview context 构造

- [x] BattleSkinHelper
  - texture cache
  - atlas frame cache
  - style cache
  - card / badge / momentum dot 样式缓存

- [x] BattleActorRenderHelper
  - 角色显示边界统一
  - 非标准 sheet 避免强制裁帧
  - 标准横向 sheet 才走 atlas frame
  - 角色脚底锚点统一
  - 角色动画落点统一

- [x] cached visual controller（wrapper）
  - 接入 Stage / HUD / Skin / Actor helper
  - 保留对象池、diff、apply、原始输入采集

---

## 已完成（性能关键路径）

### Stage 渲染
- [x] grid 几何缓存
- [x] grid 差量更新（仅更新变化 slot）
- [x] grid slot 状态构造下沉到 BattleStageHelper

### Overlay
- [x] range overlay 对象池（Polygon2D / Line2D 复用）
- [x] range overlay 颜色 / 线宽 / 层级配置下沉到 BattleStageHelper

### HUD
- [x] intent 文案下沉到 BattleHudHelper
- [x] intent 文案缓存化
- [x] effect preview 文案下沉到 BattleHudHelper
- [x] effect preview 文案缓存化
- [x] effect preview context 推导下沉到 BattleHudHelper

### Actor
- [x] 角色显示边界下沉
- [x] 角色强制裁帧逻辑收口
- [x] 角色脚底锚点下沉
- [x] 角色动画落点下沉

---

## 当前进行中

### Controller 最终收口

- [x] grid 状态判断从 cached controller 下沉
- [x] effect preview 文案从 cached controller 下沉
- [x] effect preview context 推导从 cached controller 下沉
- [x] range overlay 配置从 cached controller 下沉
- [x] actor render bounds / frame / anchor 从 cached controller 下沉
- [ ] cached visual controller 最终职责检查：只保留 input collection / diff / pool / apply

---

## 待验证

### 本地 Godot
- [ ] Godot Editor 编译无 warning-as-error
- [ ] MainVisual 正常进入
- [ ] 字符入口仍可进入
- [ ] 视觉入口角色完整显示，脚底不被裁剪
- [ ] 战斗主流程可点击、可出牌、可预览

### Web
- [ ] Web export 成功
- [ ] 浏览器运行无 Console error
- [ ] 中文字体正常显示
- [ ] 角色完整显示，显示边界与脚底锚点基本匹配
- [ ] Range overlay 无明显节点创建抖动

---

## 下一刀建议

优先做一次“编译与运行验收”，而不是继续盲目拆：

1. 本地 `git pull`
2. Godot Editor 跑 MainVisual
3. 修所有 warning-as-error / signature mismatch
4. Web export 跑 `./tools/build_and_serve_web.sh`
5. 根据浏览器实际截图微调 Actor helper：
   - `ACTOR_RENDER_SIZE`
   - `ACTOR_FOOT_OFFSET_X`
   - `ACTOR_GROUND_Y`

---

## 当前结论

Milestone D 的主要结构重构已经基本落地：Stage、HUD、Skin、Actor 都已经从 controller 中拆出。cached visual controller 当前更接近绑定层，但仍需一次最终职责审查和运行验收。

下一阶段的重点不是继续堆 helper，而是：

- 保证 Godot 编译无错误
- 保证 Web 可导出
- 保证中文字体、角色显示、战斗交互三条主链路稳定
- 根据真实截图微调 Actor helper 参数
