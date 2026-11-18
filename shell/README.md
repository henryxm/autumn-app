# Autumn Ops Shell

独立运维证书控制台。三端说明见上级 [`../README.md`](../README.md)。

## Android Studio

与超然信打开 `crchat_flutter/` 一样，**本目录才是 Flutter 工程根**（含 `pubspec.yaml`）。

```bash
open -a "Android Studio" "$(pwd)"
```

不要打开上级 `autumn-app/`：根目录没有 `pubspec.yaml`，设备栏/Flutter 工具会不完整（往往只剩 macOS）。

## 命令行

```bash
export PATH="/Users/mac/hamony/flutter/bin:$PATH"
export LANG=en_US.UTF-8

flutter pub get
flutter run -d android
flutter run -d ios
flutter run -d ohos    # 需 DevEco 签名 + 鸿蒙设备
```
