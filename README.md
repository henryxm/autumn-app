# Autumn Ops App

**Autumn 运维管理**客户端：协议库、运维界面，以及可独立安装的启动壳。  
对接 Autumn 服务端运维通道（`/ops/api/v1`）；协议说明见框架文档 `docs/AI_OPS_CERT.md`（本机常并列 `../autumn/docs/AI_OPS_CERT.md`）。

用本项目可以：

- **单独使用**：编译运行 `shell/`，得到运维 App（包名 `cn.org.autumn.ops`），完成站点探测、证书入驻与日常运维。
- **嵌进自己的应用**：用 git / CocoaPods 引入 `packages/*` 或 `ios/*`，挂上公开入口即可。
- **先体验完整流程**：安装 **超然信**（已内置本运维能力）。官网 https://chaoran.xin/ ；应用市场搜索「超然信」；或打开站点 `{baseUrl}/ops/discover`（发现页开启时会引导下载并添加该站）。

## 目录

```text
autumn-app/
  packages/autumn_ops/      # Flutter 协议客户端
  packages/autumn_ops_ui/   # Flutter Material 多站点列表/添加/管理
  ios/AutumnOpsCore/        # 原生 CocoaPods：协议（对齐 autumn_ops）
  ios/AutumnOpsUI/          # 原生 CocoaPods：Gate/管理（对齐 autumn_ops_ui）
  shell/                    # 独立运维壳（Android / iOS / HarmonyOS / macOS / Web）
  docs/                     # 发版与第三方整合说明
  .vscode/                  # 编辑器调试配置
```

- Flutter / Dart 宿主：见 [docs/PACKAGES_RELEASE_AND_CONSUMER.md](docs/PACKAGES_RELEASE_AND_CONSUMER.md)
- iOS 原生宿主：见 [docs/IOS_PACKAGES_CONSUMER.md](docs/IOS_PACKAGES_CONSUMER.md)

## 环境

| 工具 | 说明 |
|------|------|
| Flutter SDK | 稳定渠道即可；若需编鸿蒙，使用支持 OHOS 的 Flutter 发行版 |
| Android SDK / Xcode 15+ | 常规移动端调试 |
| DevEco Studio | 仅鸿蒙：`shell/ohos` 签名与 Sync |

```bash
# 按本机 Flutter 安装调整 PATH
export LANG=en_US.UTF-8   # CocoaPods 需要 UTF-8

cd shell
flutter pub get
```

鸿蒙若使用 CPF-Flutter 系插件，可在宿主或 `shell` 用 `dependency_overrides` 拉齐 `path_provider` / `share_plus` 等（见 `shell/pubspec.yaml` 注释）。

## Android Studio / 工程根

本仓的 Flutter **应用根是 `shell/`**（含 `pubspec.yaml`），不要只打开仓库根目录。

```bash
open -a "Android Studio" "$(pwd)/shell"
# 或 File → Open → 选择 autumn-app/shell/
```

打开正确后应出现 Flutter 设备栏与 `main.dart` 运行配置。鸿蒙请用 **DevEco Studio** 打开 `shell/ohos`。

## Cursor 调试

可用仓库根（已配 `.vscode`）。Run and Debug：

| 配置 | 说明 |
|------|------|
| **shell · Android / iOS / HarmonyOS** | 对应设备 |
| **shell · macOS / Chrome** | 本机快速联调 |

## 命令行（独立壳）

```bash
cd shell

flutter run -d android
flutter build apk

flutter run -d ios
flutter build ios --no-codesign

flutter run -d ohos      # 需 DevEco 签名
flutter build hap

flutter run -d macos
```

### Harmony 签名

`shell/ohos/build-profile.json5` 的 `signingConfigs` 默认为空。  
首次真机请在 DevEco 为 `cn.org.autumn.ops` 配置签名后 Sync；勿复用其他产品的证书配置。

### 多设备与恢复（协议摘要）

1. **首次**：探测 → 粘贴服务器日志 `OpsEnroll secret=` → 入驻。  
2. **第二台起**：已登录设备在「证书」页签发认领码 → 新设备「认领码入驻」。  
3. **同证共享**：设分享口令 → **分享到聊天**（宿主注入 IM，消息类型 `AutumnOps`）或导出凭证文件 → 对端 Gate / 选文件导入（同一 `certId`）。  
4. **唯一设备丢失**：服务端 wall 重置运维证书或清空 `SECURITY_OPS_CERT_CONFIG` 后重启 → 新 OpsEnroll 再入驻。

## 依赖关系

```text
shell → autumn_ops_ui → autumn_ops
嵌入宿主 → autumn_ops_ui → autumn_ops   # 或 iOS：AutumnOpsUI → AutumnOpsCore
```

本地证书落在**当前 App 沙盒**；不同 Bundle / 应用 ID 互不共享。跨应用同证：IM `AutumnOps` 或凭证文件。

## 代码结构规范（硬规则）

`packages/`（及对称的 `ios/`）是运维**唯一业务与界面实现面**。`shell/` 与任意嵌入宿主只做薄壳：启动、主题、路由挂载。须通过同一版本 packages 获得一致能力，禁止在宿主侧分叉实现运维 UI。

| 层 | 包/目录 | 允许 | 禁止 |
|----|---------|------|------|
| 协议 | `packages/autumn_ops` | HTTP/RSA/证书/探测/`AutumnOpsPayload`/`OpsStore` | Flutter 业务页面 |
| 界面 | `packages/autumn_ops_ui` | 运维 Page/表单/导入导出；稳定公开入口 | 依赖具体宿主包名 |
| 独立壳 | `shell/` | `main`、主题、平台工程 | 运维业务逻辑 |
| 嵌入宿主 | 你的 App | git/Pods 依赖；挂载公开入口；产品门禁 | 复制/重写运维页；长期 path 提交进仓库 |

**公开入口（宿主只挂这些）**

- `AutumnOpsHome` — 多站点首页  
- `AutumnOpsGatePage` — 深链 / 消息载荷 / 发现 URL 入 Gate  
- `OpsKeyboardDismiss` — 可选，供 `MaterialApp.builder`

## 如何整合到其它应用（摘要）

```yaml
# Flutter 宿主 pubspec.yaml（钉 tag，勿长期 ref: main）
autumn_ops_ui:
  git:
    url: https://github.com/henryxm/autumn-app.git
    ref: ops-v0.1.0
    path: packages/autumn_ops_ui
```

1. 依赖 `autumn_ops_ui`（会拉上 `autumn_ops`）。  
2. 路由中挂载 `AutumnOpsHome` / `AutumnOpsGatePage`（或等价包装）。  
3. 可选：实现分享钩子，将 `AutumnOps` 载荷发到你的 IM / 选人流程。  
4. 发现页：打开 `{site}/ops/discover` 或宿主自定义 scheme（解析逻辑见 `AutumnOpsDiscover`）。  
5. 发版跟版、SemVer、联调 overrides：见 [docs/PACKAGES_RELEASE_AND_CONSUMER.md](docs/PACKAGES_RELEASE_AND_CONSUMER.md)。  
6. iOS 原生：见 [docs/IOS_PACKAGES_CONSUMER.md](docs/IOS_PACKAGES_CONSUMER.md)。

发版主链：`packages` 变更 → `shell` 验收 → 推送 `main` → annotated tag `ops-vX.Y.Z` → 各嵌入宿主改 `ref` / Pod 工作树。

## 添加站点 · 地址探测

| 输入 | 探测顺序 |
|------|----------|
| `example.com` / `host:port/path` | `https://…` → 失败再 `http://…` |
| `192.168.1.10` / `[fd00::1]:8080` | 仅 `http://…` |
| 已带 `http://` 或 `https://` | 按原文探测 |

Android / iOS 需允许内网明文 HTTP 时按各平台网络安全配置处理。
