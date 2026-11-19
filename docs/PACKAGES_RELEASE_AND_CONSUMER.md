# Autumn Ops packages：发版、标签与外部宿主整合（最佳实践）

本文是 **源仓权威流程**。超然信侧消费说明见：  
`chaoranxin_flutter/crchat_flutter/lib/doc/AUTUMN_OPS_GIT_DEP.md`。

分层硬规则摘要见仓库根 [README.md](../README.md)「代码结构规范」。

---

## 1. 角色与仓库

| 角色 | 仓库 | 职责 |
|------|------|------|
| **源仓** | `https://git.minclouds.com/henryxm/autumn-app.git` | `packages/autumn_ops`、`packages/autumn_ops_ui`（Flutter）与 `ios/AutumnOpsCore`、`ios/AutumnOpsUI`（原生 Pod）同仓实现；`shell/` 仅薄壳验证 |
| **产品宿主（Flutter）** | 如 `chaoranxin_flutter` → `crchat_flutter` | **git 子路径**引用 packages；只挂载公开入口，不写运维业务 UI |
| **产品宿主（iOS）** | XSVideo / XSign | CocoaPods path 引用 `ios/*`；`AutumnOpsNativeHost` 薄壳；见 [IOS_PACKAGES_CONSUMER.md](IOS_PACKAGES_CONSUMER.md) |
| **独立壳** | 本仓 `shell/` | 本地 `path:` 引用 packages；发版前在此做功能验收 |

```text
开发者改 packages
    → shell 本地 path 验证
    → merge main + 打 tag + push tag
    → 产品仓改 pubspec ref → flutter pub get
    → 产品仓只测入口挂载 / 门禁 / 沙盒
```

---

## 2. 代码落点（变更前必查）

| 变更类型 | 改哪里 | 禁止 |
|----------|--------|------|
| 协议、模型、加解密、本地 store | `packages/autumn_ops`（Flutter）/ `ios/AutumnOpsCore`（原生） | 写业务页；两端行为以 `AI_OPS_CERT` 为准 |
| 运维页面、表单、导入导出 UI | `packages/autumn_ops_ui` / `ios/AutumnOpsUI` | import shell / 产品 App |
| App 名、主题、平台工程、鸿蒙 override | `shell/` | 运维业务逻辑 |
| 入口导航、谁能打开运维 | 产品宿主（Flutter `AutumnOpsHost` / iOS `AutumnOpsNativeHost`） | 复制/重写运维页 |

公开入口（宿主只挂这些）：

- `AutumnOpsHome` — 多站点首页（独立 shell）
- `AutumnOpsGatePage` — 产品深链：IM `AutumnOps` content / `{base}/ops/discover` 自动探测（超然信）
- `AutumnOpsDiscover` — 解析/生成发现 URL（逻辑在 `autumn_ops`）
- `OpsKeyboardDismiss` — 可选，供宿主 `MaterialApp.builder`

产品默认**无常驻入口**；经 `AutumnOps` 消息、收藏、扫码/链接发现进入。

---

## 3. 版本与标签约定

### 3.1 Tag 命名

- 格式：`ops-vMAJOR.MINOR.PATCH`（例：`ops-v0.1.0`、`ops-v0.2.0`）
- 使用 **annotated tag**，打在 **已推送到 `origin/main` 的 commit** 上
- 前缀 `ops-`：与本仓其它潜在 tag 区分，且与 pub `ref` 一一对应
- **同一 tag 同时覆盖** Dart `packages/*` 与 iOS `ios/AutumnOps*`（不另开 `ops-ios-v*`，避免双轨）

### 3.2 SemVer 口径（packages 对宿主）

| 变更 | 版本 | 例 |
|------|------|-----|
| 修复、文案、内部重构，公开 API/交互契约不变 | PATCH | `0.1.0` → `0.1.1` |
| 新增能力、新入口导出、可兼容的 UI 增强 | MINOR | `0.1.1` → `0.2.0` |
| 破坏性：删除/改名公开导出、AutumnOps 载荷不兼容、强制宿主改代码 | MAJOR | `0.2.0` → `1.0.0` |

包内 `pubspec.yaml` 的 `version:` 建议与即将发布的 tag 数字部分对齐（如 tag `ops-v0.2.0` → `version: 0.2.0`），便于对照。

### 3.3 产品仓 `ref` 规则（双轨）

| 场景 | `ref` / 手段 | 说明 |
|------|--------------|------|
| **稳定（默认，可提交 / CI）** | **`ops-v*` tag** 或完整 SHA | 宿主 `pubspec.yaml` **禁止**长期 `ref: main` |
| **本机联调** | gitignore 的 `pubspec_overrides.yaml`（path 或临时 main） | 见超然信 `pubspec_overrides.yaml.example`；勿提交 |
| **源仓发版** | `./scripts/release_ops_tag.sh X.Y.Z "说明"` | bump packages + ios podspec → annotated tag → push |
| **宿主跟版** | `./scripts/sync_autumn_ops.sh ops-vX.Y.Z` | 改 yaml ref + `flutter pub get` → 提交 yaml/lock |

`pubspec.lock` 会钉死 resolved commit；换 tag 后必须跑 sync 脚本或等价 `pub get`，并提交 lock。
---

## 4. 源仓标准发版流程（逐步）

### 4.1 开发

```bash
cd /path/to/autumn-app
# 功能只改 packages/；shell 仅必要时动 main/主题/平台配置
cd shell && flutter pub get && flutter run -d <device>
```

验收建议（按改动范围勾选）：

- [ ] 探测 / 首次口令入驻
- [ ] 认领码入驻
- [ ] AutumnOps 分享到聊天与凭证导入
- [ ] 证书签发 / 撤销
- [ ] 管理 IP / gate（若涉及）
- [ ] shell 与预期产品入口打开的是同一套 UI（同源 packages）

### 4.2 合入 main

```bash
git checkout main
git pull origin main
# … PR merge 或本地 merge …
git status   # 工作区干净
git log -1 --oneline
```

确认远端已有该 commit：

```bash
git push origin main   # 若尚未推送
```

### 4.3 打 tag 并推送（推荐脚本）

```bash
# 工作区干净，且已与 origin/main 对齐
./scripts/release_ops_tag.sh 0.2.0 "一句话变更说明"
git push origin main
git push origin ops-v0.2.0
git ls-remote --tags origin ops-v0.2.0
```

手打 tag 亦可，但须同步 bump `packages/*/pubspec.yaml` 与 `ios/*/ *.podspec` 的 `version`。

**注意：**

- Tag 必须指向 **已在 origin 上的 commit**，否则产品 `flutter pub get` 拉不到。
- 已发布 tag **不要改写 / 力推覆盖**；纠错打新 PATCH tag。
- README / 文档里的示例 `ref:` 随发版更新到最新稳定 tag。

### 4.4 通知宿主跟版

在发版说明（MR/聊天/Changelog）中写清：

1. 新 tag 名（如 `ops-v0.2.0`）
2. 是否破坏公开入口 / `AutumnOps` / `autumn-ops` 载荷
3. 产品侧是否需要改挂载代码（通常不需要）
4. 建议验收项

---

## 5. 产品宿主（超然信）跟版流程

权威消费文档：`crchat_flutter/lib/doc/AUTUMN_OPS_GIT_DEP.md`。摘要：

1. `cd crchat_flutter && ./scripts/sync_autumn_ops.sh ops-vX.Y.Z`（无 overrides）  
2. 确认 lock 中 `resolved-ref` 对应该 tag  
3. 提交 `pubspec.yaml` + `pubspec.lock`  
4. 编译；运维卡 / 发现 / 分享冒烟  
5. **不要**为跟版在产品仓新增运维业务页  

`share_plus` 等须继续由宿主 `dependency_overrides` 收敛到 CPF git（与 shell 同策略），否则 hosted/git 双源会导致 pub 失败。

---

## 6. 本机双仓并行开发（热验证）

仅个人本机：产品仓使用 **gitignore** 的 `pubspec_overrides.yaml` 指向本地 packages path。  
**禁止**把个人 path 写进已提交的 `pubspec.yaml`。

联调结束：删除 overrides → `flutter pub get` → 确认仍解析远程 tag。

详见超然信 `AUTUMN_OPS_GIT_DEP.md`「本机联调」。

---

## 7. 权限与 CI

- 所有需要 `flutter pub get` 的开发者 / CI Runner，须对 `autumn-app` 私有仓有 **读** 权限（HTTPS 凭据或 SSH）。
- CI 应钉 tag 或 SHA，禁止 `ref: main`。
- 证书数据按 **宿主 App 沙盒** 隔离；独立 shell 与超然信不自动共享；同证共享用 IM `AutumnOps` 或凭证文件。

---

## 8. 常见问题

| 现象 | 原因 | 处理 |
|------|------|------|
| `pub get` 找不到 tag | tag 未 push / 拼写错误 | `git push origin ops-vX.Y.Z` |
| hosted 与 git 的 `share_plus` 冲突 | UI 包声明 hosted，宿主用 CPF | 宿主 `dependency_overrides` 强制 CPF |
| 产品有功能、shell 没有（或相反） | 业务写进了某一宿主 | 迁回 packages，宿主只留入口 |
| 改了 packages 产品看不到 | 未打 tag 或产品未改 `ref` | 走 §4 → §5；或临时 overrides |
| 两台设备证书不一致 | 不同 Bundle 沙盒 | 预期行为；用 AutumnOps / 凭证互通 |

---

## 9. 检查清单（发版人）

- [ ] 变更只在 `packages/`（壳层除外）
- [ ] `shell` 本地跑通相关用例
- [ ] `main` 已推送
- [ ] annotated tag `ops-vX.Y.Z` 已推送
- [ ] 包 `version` 与 tag 数字对齐（建议）
- [ ] 已通知产品更新 `ref` 与验收项
- [ ] 未改写历史 tag
