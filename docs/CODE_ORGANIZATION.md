# 代码组织原则归档

当前工程协作入口已迁移到 [ENGINEERING.md](ENGINEERING.md)。本文原本记录文件体积、职责拆分、继承链治理、AI 协作和验证要求；核心规则已并入工程总入口。

保留结论：

- 单个 `.gd` 脚本建议控制在 25KB 以下，新增 GDScript 默认控制在 20KB 以下。
- Controller 只做调度，不长期承载 UI、状态推进、debug、数据生成和战斗桥接等多重职责。
- 不继续新增 controller 继承层，新功能优先使用 helper / runtime / view / formatter / bridge。
- 大文件不做远端整文件替换；优先小补丁和小 helper。

后续工程规则直接维护 [ENGINEERING.md](ENGINEERING.md)。
