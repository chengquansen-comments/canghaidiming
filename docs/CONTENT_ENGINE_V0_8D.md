# Content Engine v0.8d

## 1) v0.8d 定位

v0.8d 是 Godot loader preflight（接入前分析与预检），不是 loader implementation。
本阶段只输出预检报告，不新增 loader 脚本，不修改任何 Godot 运行时逻辑或战斗逻辑。

## 2) 为什么不能直接接 Godot loader

当前阶段仍处于 runtime content 治理链路阶段：

- 先保证 manifest / checksum / fingerprint 一致性
- 先明确失败模式与 fallback
- 先明确 touchpoints 风险

在没有 preflight 的情况下直接接 loader，会把数据治理风险直接带入运行时路径。

## 3) manifest-first 原则

未来 Godot 接入应采用 manifest-first：

1. 先读取 `runtime_manifest.json`
2. 校验 `sha256` / `file_size_bytes` / fingerprints
3. 仅在校验通过后做只读 runtime probe

不建议 direct runtime file read 作为默认路径，因为会绕过治理信息与一致性校验。

## 4) failure mode 要求

未来 loader 必须 fail-closed 或 fallback：

- `fail_closed`
- `fallback_to_existing_design_data`
- `fallback_to_static_runtime_data`

并且每个 runtime domain 都必须有明确 fallback source。

## 5) proposed_godot_touchpoints 说明

preflight 中出现的 `proposed_godot_touchpoints` 仅是 future_touchpoint_only 建议，
不代表本阶段有任何文件修改。

## 6) 后续阶段建议

- v0.8e 可以考虑 read-only loader scaffold
- 但仍不替换正式数据源
- 正式运行时切换需在更后阶段并经过独立验收

## 7) Godot hygiene 说明

RID/ObjectDB/resource leak warning 仍作为独立 Godot hygiene issue，
不作为 content engine v0.8d preflight 阻塞项。
