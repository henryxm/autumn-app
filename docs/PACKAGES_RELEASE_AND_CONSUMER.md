# Autumn Ops packages：发版、标签与嵌入整合

本文是 **源仓权威流程**：如何发版本仓 packages / iOS Pods，以及如何把运维能力嵌进其它应用。  
项目用法见仓库根 [README.md](../README.md)。

---

## 1. 角色与仓库

| 角色 | 仓库 / 位置 | 职责 |
|------|-------------|------|
| **源仓** | `https://github.com/henryxm/autumn-app.git` | `packages/autumn_ops`、`packages/autumn_ops_ui`（Flutter）与 `ios/AutumnOpsCore`、`ios/AutumnOpsUI`（原生 Pod）；`shell/` 独立运维壳与发版验收 |
| **独立壳** | 本仓 `shell/` | 本地 `path:` 引用 packages；可单独发版为运维 App |
| **嵌入宿主（Flutter）** | Flutter / Dart 应用 | **git 子路径**引用 packages；只挂载公开入口，不写运维业务 UI |
| **嵌入宿主（iOS）** | UIKit / CocoaPods 工程 | path 或固定 revision 引用 `ios/*`；薄壳挂载；见 [IOS_PACKAGES_CONSUMER.md](IOS_PACKAGES_CONSUMER.md) |

```text
开发者改 packages
    → shell 本地 path 验证（独立运行）
    → merge main + 打 tag + push tag
    → 各嵌入宿主改 pubspec / Pod 工作树 ref
    → 宿主只测入口挂载 / 门禁 / 沙盒
```

---

## 2. 代码落点（变更前必查）

| 变更类型 | 改哪里 | 禁止 |
|----------|--------|------|
| 协议、模型、加解密、本地 store | `packages/autumn_ops`（Flutter）/ `ios/AutumnOpsCore`（原生） | 写业务页；两端行为以 Autumn `AI_OPS_CERT` 为准 |
| 运维页面、表单、导入导出 UI | `packages/autumn_ops_ui` / `ios/AutumnOpsUI` | import shell / 具体产品 App |
| App 名、主题、平台工程、鸿蒙 override | `shell/` | 运维业务逻辑 |
| 入口导航、谁能打开运维 | 第三方宿主薄壳 | 复制/重写运维页 |

公开入口（宿主只挂这些）：

- `AutumnOpsHome` — 多站点首页（独立 shell 与多数宿主）
- `AutumnOpsGatePage` — 深链：IM `AutumnOps` content / `{base}/ops/discover` / 宿主自定义 URL scheme
- `AutumnOpsDiscover` — 解析/生成发现 URL（逻辑在 `autumn_ops`）
- `OpsKeyboardDismiss` — 可选，供宿主 `MaterialApp.builder`

宿主可按产品策略决定是否常驻入口；亦可仅经 `AutumnOps` 消息、收藏、扫码/链接发现进入。

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

### 3.3 宿主 `ref` 规则

| 场景 | `ref` / 手段 | 说明 |
|------|--------------|------|
| **稳定（默认，可提交 / CI）** | **`ops-v*` tag** 或完整 SHA | 宿主 `pubspec.yaml` **禁止**长期 `ref: main` |
| **本机联调** | gitignore 的 `pubspec_overrides.yaml`（path 或临时 main） | 见 §6；勿提交个人绝对路径 |
| **源仓发版** | `./scripts/release_ops_tag.sh X.Y.Z "说明"` | bump packages + ios podspec → annotated tag → push |
| **宿主跟版** | 改 `ref` + `flutter pub get`（可自写 sync 脚本） | 提交 yaml / lock |

`pubspec.lock` 会钉死 resolved commit；换 tag 后必须 `pub get`，并提交 lock。

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
- [ ] shell 与预期宿主入口打开的是同一套 UI（同源 packages）

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

- Tag 必须指向 **已在 origin 上的 commit**，否则宿主 `flutter pub get` 拉不到。
- 已发布 tag **不要改写 / 力推覆盖**；纠错打新 PATCH tag。
- README / 文档里的示例 `ref:` 随发版更新到最新稳定 tag。

### 4.4 通知宿主跟版

在发版说明（MR/Changelog）中写清：

1. 新 tag 名（如 `ops-v0.2.0`）
2. 是否破坏公开入口 / `AutumnOps` / `autumn-ops` 载荷
3. 宿主侧是否需要改挂载代码（通常不需要）
4. 建议验收项

---

## 5. 嵌入 Flutter 宿主：接入与跟版

### 5.1 依赖声明

```yaml
dependencies:
  autumn_ops_ui:
    git:
      url: https://github.com/henryxm/autumn-app.git
      ref: ops-v0.1.0   # 钉 tag；禁止长期 main
      path: packages/autumn_ops_ui
```

`autumn_ops_ui` 会传递依赖 `autumn_ops`。若宿主平台插件源与 UI 包声明冲突（例如鸿蒙 federated `share_plus`），在宿主用 `dependency_overrides` 收敛到统一源。

### 5.2 挂载入口

1. 路由打开 `AutumnOpsHome`（多站点）或按需直接 `AutumnOpsGatePage`。  
2. 解析到发现 URL / 自定义 scheme 时，用 `AutumnOpsDiscover`（或 UI 包封装）进入 Gate。  
3. 可选：`AutumnOpsShareHooks.toChat` 注入「分享到聊天」——由宿主实现选人 / IM 发送，消息类型建议 `AutumnOps`，载荷字段与协议文档一致。  
4. **不要**在宿主仓复制运维页面或长期 `path:` 提交进仓库。

### 5.3 跟版

```bash
# 示例：手改 ref 后
cd /path/to/your_app
# 编辑 pubspec.yaml → ref: ops-vX.Y.Z
flutter pub get
git add pubspec.yaml pubspec.lock
# 编译；冒烟：入驻 / 发现 / 分享导入（若已接 IM）
```

可自备 `sync_autumn_ops.sh`：改 yaml `ref` + `flutter pub get`。  
**不要**为跟版在宿主仓新增运维业务页。

---

## 6. 本机双仓并行开发（热验证）

仅个人本机：宿主使用 **gitignore** 的 `pubspec_overrides.yaml`：

```yaml
# pubspec_overrides.yaml（勿提交）
dependency_overrides:
  autumn_ops:
    path: /absolute/path/to/autumn-app/packages/autumn_ops
  autumn_ops_ui:
    path: /absolute/path/to/autumn-app/packages/autumn_ops_ui
```

**禁止**把个人 path 写进已提交的 `pubspec.yaml`。

联调结束：删除 overrides → `flutter pub get` → 确认仍解析远程 tag。

---

## 7. 权限与 CI

- 对公开 GitHub 仓：CI / 开发者只需能 `git clone` / `flutter pub get`。若你 fork 为私有镜像，Runner 需对该镜像有读权限。  
- CI 应钉 tag 或 SHA，禁止 `ref: main`。  
- 证书数据按 **宿主 App 沙盒** 隔离；独立 `shell` 与其它嵌入 App **互不自动共享**；同证共享用 IM `AutumnOps` 或凭证文件。

---

## 8. 常见问题

| 现象 | 原因 | 处理 |
|------|------|------|
| `pub get` 找不到 tag | tag 未 push / 拼写错误 | `git push origin ops-vX.Y.Z` |
| hosted 与 git 的 `share_plus` 等冲突 | UI 包声明与宿主平台插件源不一致 | 宿主 `dependency_overrides` 强制同一源 |
| 某一宿主有功能、shell 没有（或相反） | 业务写进了某一宿主 | 迁回 packages，宿主只留入口 |
| 改了 packages 宿主看不到 | 未打 tag 或宿主未改 `ref` | 走 §4 → §5；或临时 overrides |
| 两台设备证书不一致 | 不同 Bundle 沙盒 | 预期行为；用 AutumnOps / 凭证互通 |

---

## 9. 检查清单（发版人）

- [ ] 变更只在 `packages/` / `ios/`（壳层除外）
- [ ] `shell` 本地跑通相关用例
- [ ] `main` 已推送
- [ ] annotated tag `ops-vX.Y.Z` 已推送
- [ ] 包 `version` 与 tag 数字对齐（建议）
- [ ] 已通知宿主更新 `ref` 与验收项
- [ ] 未改写历史 tag
