# Autumn Ops Shell

独立运维壳：编译后即可使用运维证书控制台。总说明见 [`../README.md`](../README.md)。

## Android Studio

**本目录才是 Flutter 工程根**（含 `pubspec.yaml`）。不要打开上级 `autumn-app/`：根目录没有 `pubspec.yaml`，设备栏/Flutter 工具会不完整。

```bash
open -a "Android Studio" "$(pwd)"
```

## 命令行

```bash
# 按本机 Flutter 安装调整 PATH
export LANG=en_US.UTF-8

flutter pub get
flutter run -d android
flutter run -d ios
flutter run -d ohos    # 需 DevEco 签名 + 鸿蒙设备
```
