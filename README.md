# Autumn Ops App

Autumn 运维证书**独立客户端**（协议 lib + UI lib + Flutter 启动壳）。  
协议 SSOT 在 Autumn 服务端仓库：[`docs/AI_OPS_CERT.md`](https://git.minclouds.com/cloud/autumn)（或本地并列的 `../autumn/docs/AI_OPS_CERT.md`）。

## 目录

```text
autumn-app/
  packages/autumn_ops/      # 协议客户端（probe/enroll/session/adminip/gate/ipwhite/ipblack）
  packages/autumn_ops_ui/   # Material 多站点列表/添加/管理
  shell/                    # 独立 Flutter App 壳（cn.org.autumn.ops）
```

产品 App（超然信 / XSign / XSVideo）暂不内嵌；运维使用本壳打包运行。

## 环境

需要本机 Flutter SDK（`^3.6`）。

```bash
cd shell
flutter pub get
flutter run
flutter build apk
# flutter build ipa   # 需本机签名
```

## 依赖关系

```text
shell → autumn_ops_ui → autumn_ops
```

本地证书落在本 App 沙盒 `Application Support/autumn_ops/`；与产品 App 不共享。可通过管理页「导出口令包 → 导入」迁移。
