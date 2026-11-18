# Autumn Ops App

Autumn 运维证书**独立客户端**（协议 lib + UI lib + Flutter 启动壳）。  
协议 SSOT 在 Autumn 服务端仓库：[`docs/AI_OPS_CERT.md`](https://git.minclouds.com/cloud/autumn)（或本地并列的 `../autumn/docs/AI_OPS_CERT.md`）。

## 目录

```text
autumn-app/
  packages/autumn_ops/      # 协议客户端
  packages/autumn_ops_ui/   # Material 多站点列表/添加/管理
  shell/                    # Flutter 壳（Android / iOS / HarmonyOS / macOS / Web）
  .vscode/                  # Cursor 调试配置
```

统一包名 / Bundle ID：`cn.org.autumn.ops`

## 环境（对齐 chaoranxin_flutter）

| 工具 | 本机约定 |
|------|----------|
| Flutter SDK | `/Users/mac/hamony/flutter`（OHOS 定制，亦可编 Android/iOS） |
| Android SDK | `/Users/mac/Library/Android/sdk` |
| Xcode | 15+ |
| DevEco Studio | 鸿蒙 SDK + 签名（`shell/ohos/local.properties`） |

```bash
export PATH="/Users/mac/hamony/flutter/bin:$PATH"
export LANG=en_US.UTF-8   # CocoaPods 需要 UTF-8

cd shell
flutter pub get
```

鸿蒙依赖走 CPF-Flutter（与超然信相同）：`path_provider` / `path_provider_ohos` / `share_plus`。

## Android Studio（对齐 chaoranxin_flutter）

超然信是打开 **`crchat_flutter/`**（有 `pubspec.yaml` 的应用目录），不是上一级仓库根。  
本仓同理：**请打开 `shell/`，不要打开 `autumn-app/` 根目录**。

```bash
# 推荐：打开 shell（有 pubspec.yaml 的 Flutter 工程根）
open -a "Android Studio" "$(pwd)/shell"

# 或 File → Open → 选本仓下的 shell/
```

打开正确后应出现：Flutter 设备栏（Android / iOS / macOS / Chrome…）、`main.dart` 运行配置、Run/Debug、Pub get 等工具条。

| 工程 | 应对齐打开的目录 |
|------|------------------|
| 超然信 | `chaoranxin_flutter/crchat_flutter` |
| Autumn 运维 | `autumn-app/shell` |

鸿蒙调试用 **DevEco Studio** 打开 `shell/ohos`（Android Studio 不跑 ohos 设备）。

## Cursor 调试

Cursor 可用仓库根目录（已配 `.vscode`）。Run and Debug：

| 配置 | 说明 |
|------|------|
| **shell · Android** | 当前 Android 设备 |
| **shell · iOS** | 当前 iOS 设备 |
| **shell · HarmonyOS** | 当前 ohos 设备（需 DevEco 签名） |
| **shell · macOS** / **Chrome** | 本机快速联调 |

## 命令行

```bash
cd shell

# Android
flutter run -d android
flutter build apk

# iOS（本机已配 DEVELOPMENT_TEAM）
flutter run -d ios
flutter build ios --no-codesign   # 仅编译校验

# HarmonyOS（需连接鸿蒙设备或模拟器，并在 DevEco 配置签名）
flutter run -d ohos
flutter build hap

# 本机
flutter run -d macos
```

### Harmony 签名

`shell/ohos/build-profile.json5` 的 `signingConfigs` 默认为空。  
首次真机调试请在 DevEco 打开 `shell/ohos`，为 `cn.org.autumn.ops` 配置自动签名或手动证书后 Sync；勿直接复用超然信 `com.chaoranxin.chat` 证书。

### 多设备与恢复（协议摘要）

1. **首次**：探测 → 粘贴服务器日志 `OpsEnroll secret=` → 入驻。  
2. **第二台起**：已登录设备在「证书」页签发认领码 → 新设备添加站点 →「认领码入驻」。  
3. **同证备份/换机**：已登录设备在「证书」页设分享口令 → 导出 `.ops` 文件并分享 → 新手机「+」探测同一地址 →「换机备份」→ **选择该文件**并填同一口令（共享同一 certId）。勿与「认领码」（文字）混淆。  
4. **唯一设备丢失**：wall 重置运维证书（需 clearToken）或 DB 清空 `SECURITY_OPS_CERT_CONFIG` 后重启 → 新 OpsEnroll 再入驻。

## 依赖关系

```text
shell → autumn_ops_ui → autumn_ops
```

本地证书落在本 App 沙盒 `Application Support/autumn_ops/`；与产品 App 不共享。换机：管理页导出 `.ops` → 新设备「+」选文件导入。

## 添加站点 · 地址探测

输入框可填**域名**或 **IP**（含内网）：

| 输入 | 探测顺序 |
|------|----------|
| `example.com` / `host:port/path` | `https://…` → 失败再 `http://…` |
| `192.168.1.10` / `[fd00::1]:8080` | 仅 `http://…` |
| 已带 `http://` 或 `https://` | **不**再自动拼接，按原文探测 |

Android / iOS 已允许明文 HTTP（内网 IP）。成功探测后输入框会回填实际可用的 Base URL。
