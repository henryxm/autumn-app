# Autumn Ops iOS Pods：消费与发版

与 [PACKAGES_RELEASE_AND_CONSUMER.md](PACKAGES_RELEASE_AND_CONSUMER.md) 对称：Dart packages 给 Flutter；**同一 annotated tag `ops-v*`** 同时覆盖 `ios/AutumnOpsCore` + `ios/AutumnOpsUI`。

协议 SSOT：Autumn `docs/AI_OPS_CERT.md`；Dart `packages/autumn_ops` 为客户端参考实现。  
用法总览见仓库根 [README.md](../README.md)。

---

## 1. 布局

```text
autumn-app/
  packages/autumn_ops/       # Flutter SSOT（保留）
  packages/autumn_ops_ui/
  ios/
    AutumnOpsCore/           # ObjC：Client / Crypto / Store / Payload / Discover
    AutumnOpsUI/             # Gate / Sites / Add / Manage 六 Tab / ShareHooks
```

| Pod | 职责 | 依赖 |
|-----|------|------|
| `AutumnOpsCore` | T0–T3 API、Security.framework 密码学、Keychain / 站点列表 | Foundation, Security |
| `AutumnOpsUI` | UIKit Gate + 管理页 | AutumnOpsCore, Masonry |

**建议**仅用系统 Security.framework；若宿主已链其它 OpenSSL 发行版，勿再为 Ops 额外链一套，以免符号冲突。

---

## 2. 宿主引用

### 2.1 本机 path 联调

```ruby
# Podfile（路径按本机布局调整）
pod 'AutumnOpsCore', :path => '../path/to/autumn-app/ios/AutumnOpsCore'
pod 'AutumnOpsUI',   :path => '../path/to/autumn-app/ios/AutumnOpsUI'
```

```bash
export LANG=en_US.UTF-8
pod install
# 源码变更后：
pod update AutumnOpsCore AutumnOpsUI
```

### 2.2 发版钉 tag（可复现）

CocoaPods **不支持** Flutter 式 `git + path` 子目录一条声明。发版推荐：

1. 源仓打 **`ops-vX.Y.Z`**（与 Dart packages 同 tag）。
2. 宿主用 **path 指向已 checkout 到该 tag 的 autumn-app 工作树**，或将 `ios/` 以 submodule / sparse checkout 固定 revision。
3. 锁 `Podfile.lock`；升级时改 checkout + `pod update AutumnOpsUI`。

`podspec` 内 `s.source` / `s.version` 与 tag 数字对齐（如 `0.1.0` ↔ `ops-v0.1.0`）。

---

## 3. 宿主薄壳（必须）

只挂入口，**不写运维业务**。推荐在宿主提供一个小的 `*Host` 类，例如：

| 能力 | 作用 |
|------|------|
| 启动时配置 | `AutumnOpsUIConfig.deviceLabel`（如 `ios-<your-app>`）+ `AutumnOpsShareHooks.toChat` |
| 打开载荷 | 气泡 / 收藏点开 → Gate（`open…Content:` / 原始 JSON） |
| 发现 URL | `{base}/ops/discover`；以及宿主注册的自定义 URL scheme（`AutumnOpsDiscover` 会识别常见 `…://…/autumnops?base=` 形态） |

`toChat`：由宿主实现选人 → 发送类型为 `AutumnOps`（或你与服务端约定的等价类型）的消息。

示例伪代码：

```objc
[AutumnOpsUIConfig shared].deviceLabel = @"ios-myapp";
[AutumnOpsShareHooks setToChat:^(NSDictionary *content, void (^done)(BOOL)) {
  // 打开选人 → 发 IM → done(YES/NO)
}];
```

---

## 4. 密钥格式（Crypto 互通）

`SecKeyCreateWithData` 对 RSA **私钥**只要 PKCS#1；Flutter `OpsCrypto.privateKeyToPem` / iOS `generateRsa2048` 存盘均为 PKCS#8（`BEGIN PRIVATE KEY`）。`AutumnOpsCrypto` 加载时须 PKCS#8→PKCS#1（公钥 SPKI→PKCS#1 作候选），否则 Gate 导入 Flutter 分享证会在 `ensureSession` 报 `SecKeyCreateWithData failed`。

## 5. 验收清单

- [ ] probe → OpsEnroll 入驻 → 管理 Tab 可读可改
- [ ] **管理壳（对齐 Flutter）**：藏系统栏时自绘顶栏；根页无死返回；Add/Recovery 有顶栏；概览卡底 `#EFEFF5`、Chip/Filled·Outlined·Tonal/令牌条对齐 M3 seed；无 UISwitch
- [ ] 认领码：A issue → B claim → 两证可独立吊销
- [ ] 分享口令 → 分享到聊天 → 对端气泡进 Gate → importWrapped
- [ ] **Flutter 签发分享证 → 本 iOS 宿主 Gate 导入 + ensureSession 成功**（不得 `SecKeyCreateWithData failed`）
- [ ] 发现 URL / 深链 / 扫码进 Gate.discover
- [ ] 管理 IP / clearToken / 删当前 IP 门禁与 Flutter 一致
- [ ] 运维消息 / 收藏入口已挂到 Gate（不再是宿主侧占位 toast）
- [ ] `Podfile.lock` 可复现；跟版步骤已写入宿主文档

---

## 6. 回滚

宿主去掉 Pod 与薄壳调用，恢复原先占位行为即可（revert 挂载提交）。
