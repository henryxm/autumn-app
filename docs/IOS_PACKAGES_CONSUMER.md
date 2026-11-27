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

**真源**：仓库**根目录** `AutumnOpsCore.podspec` / `AutumnOpsUI.podspec`（`source_files` → `ios/.../Classes`）。  
`ios/AutumnOps*/` 下的同名 podspec 仅为目录内副本，**禁止**写入宿主 Podfile（`source_files` 不同 → `Podfile.lock` 的 `SPEC CHECKSUMS` 会与发版不一致）。

### 2.1 宿主 `:git`（默认，可提交）

CocoaPods **不支持** Flutter 式 `git + 子目录 path`。

```ruby
pod 'AutumnOpsCore', :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :tag => 'ops-v0.1.21'
pod 'AutumnOpsUI',   :git => 'https://git.minclouds.com/henryxm/autumn-app.git', :tag => 'ops-v0.1.21'
```

发版可复现：源仓打 **`ops-vX.Y.Z`**（与 Dart packages 同 tag），宿主钉同一 `:tag`，并提交 `Podfile.lock`。  
同一 tag 下各机 `pod install` 的 `SPEC CHECKSUMS`（AutumnOps*）必须一致；若漂移，清缓存后重装：

```bash
rm -rf ~/Library/Caches/CocoaPods/Pods/Specs/External/AutumnOps{Core,UI}
rm -rf ~/Library/Caches/CocoaPods/Pods/External/AutumnOps{Core,UI}
export LANG=en_US.UTF-8
pod update AutumnOpsCore AutumnOpsUI
```

### 2.2 本机 path 联调（勿长期提交）

**必须**指向仓库根（与 `:git` 共用根 podspec），禁止 `.../ios/AutumnOpsCore` 或 `.../ios/AutumnOpsUI`。

```ruby
# Podfile（路径按本机布局调整）
pod 'AutumnOpsCore', :path => '../path/to/autumn-app'
pod 'AutumnOpsUI',   :path => '../path/to/autumn-app'
```

```bash
export LANG=en_US.UTF-8
pod install
# 源码变更后：
pod update AutumnOpsCore AutumnOpsUI
```

---

## 3. 宿主薄壳（必须）

只挂入口，**不写运维业务**。推荐在宿主提供一个小的 `*Host` 类，例如：

| 能力 | 作用 |
|------|------|
| 启动时配置 | `AutumnOpsUIConfig.deviceLabel`（如 `ios-<your-app>`）+ `AutumnOpsShareHooks.toChat` |
| 打开载荷 | 气泡 / 收藏点开 → Gate（`open…Content:` / 原始 JSON） |
| 发现 URL | `{base}/autumn/ops/discover`；以及宿主注册的自定义 URL scheme（`AutumnOpsDiscover` 会识别常见 `…://…/autumnops?base=` 形态） |

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
- [ ] **管理壳（对齐 Flutter）**：藏系统栏时自绘顶栏；右侧仅站点列表图标（微信小程序式圆环+中心方块），无顶栏刷新；概览/证书下拉刷新；根页无死返回；Add/Recovery 有顶栏；概览卡底 `#EFEFF5`、Chip/Filled·Outlined·Tonal/令牌条对齐 M3 seed；无 UISwitch
- [ ] **气泡打开分流**：`AutumnOpsEntry` — 本机已有同 cert 凭证时直进 Manage（不闪「导入运维凭证」）；无证时 Gate 融合口令条 + 站点/证书行 + 站点列表图标
- [ ] **站点列表**：圆角浅底行卡、本机已/未入驻+指纹、空态文案、修改名称（空则回退 URL）+删除确认；顶栏「+」添加；与 Flutter OpsSitesPage 同构
- [ ] **添加站点（对齐 Flutter OpsAddSitePage）**：三步分区（地址 → 探测结果 → 接入方式）；`OpsAddSection`/`FusedFieldAction`/`FusedActionBar`；探测语义色卡；改 URL 清空结果；`_busy` 禁用；Ready 出 tonal「本机已有证书 · 直接进入管理」（不自动跳）；`needReset` 出恢复 Outlined 并默认「凭证」；`showJoin` 仅 pending/ready/needReset；认领含 needReset；导入页内选文件+分享口令（无 Alert）；成功 `pushReplacement` Manage；顶栏/页底系统主题色
- [ ] **运行 Tab（对齐 Flutter OpsRuntimePanel）**：`AutumnOpsRuntimePanelView` 八区卡（系统/JVM/磁盘/库/防火墙/吞吐/Redis/路径）；进度条+Chip；采集时间+仅小图标刷新（16pt / 28 热区、与卡同缘右对齐 16）+下拉；卡色 highest@0.55；`ensureSession`→强类型 snapshot；失败 toast+红字；无 pretty-JSON；切 Tab / `_refreshAll` 对称 reload
- [ ] **六 Tab 共享基建**：`KeyboardDismissHelper`（滚动区点空白收键盘）；`CountChipBar` / `SwitchRow` / `RuleRowChrome`（底外距 8、`highlightedBorder`、meta）/ `StatusPill` 固有宽 hugging / `MetaChip` / `FusedDualFieldAction` 仅 Theme 色
- [ ] **管理 IP / 白名单 / 黑名单**：第一行 IP 左，右侧成组「本机→胶囊→启停」贴右；第二/三行说明与日期，删除与启停同宽槽右对齐；本机描边；黑名单语义/阈值/认领/clearToken 一致
- [ ] **IP 启停过滤 + 添加置顶**：计数条右侧文案宽「全部 / 启用中|生效中 / 已禁用|已停用」（无「加载更多」按钮，下拉刷新 + 触底静默分页）；服务端 `forbidden`/`available`；添加或认领后重置「全部」、该 IP 置顶；toast「已添加」vs「已存在，已定位」
- [ ] **盾牌**：SectionCard 三开关 + Dual fused 添加；RuleRow + CountChip；底栏开启/删除右对齐；删除走 `ConfirmPresenter`（Destructive）且按钮为 error；limit 50 分页；空/错/键盘
- [ ] **跳转**：Tonal「添加」；`JumpEditorController` FormSheet（三 Outline 字段 + enable SwitchRow，非 Alert 垫高）；底栏编辑/关闭/删除右对齐；删除 Destructive Confirm 且按钮为 error；分页/键盘
- [ ] **证书**：三区 SectionCard（设备 / 签发 / 分享）；设备行与 Flutter 同为 `RuleRowChrome`+吊销 error；Fused 签发与口令；分享区导出/导入全宽 Outlined（有间距）+ 左对齐「清除本机证书」为 error；本机高亮；最后吊销 → Recovery；切 Tab reload / 下拉刷新
- [ ] **浅/深色主题**：`AutumnOpsUITheme` 动态色；深色下盾/跳/证分区卡与规则行无近白底；运行中切换系统外观时边框与填充即时更新
- [ ] **Recovery**：编号圆点步骤 + SQL 圆角卡 + Outlined「复制数据库语句」轻 toast（非 Alert）+ Filled「我知道了」返回
- [ ] **弹窗基建**：`ConfirmPresenter`（非删除确认主钮非红）；`SecureTokenFormController`（reason + helper「在系统加固 / 安全配置中查看」）；关门禁 = 确认 → `_resolveClearTokenWithReason:` → 再关（与 Flutter 同序）；修改令牌验原令牌走 SecureToken 表单

- [ ] 认领码：A issue → B claim → 两证可独立吊销
- [ ] 分享口令 → 分享到聊天 → 对端气泡进 Gate → importWrapped
- [ ] **Flutter 签发分享证 → 本 iOS 宿主 Gate 导入 + ensureSession 成功**（不得 `SecKeyCreateWithData failed`）
- [ ] 发现 URL：仅 `{base}/autumn/ops/discover` 或 `vc/autumnops?base=` 才异步探测；探测失败走原 WebView/系统打开；成功有证直进 Manage
- [ ] 普通 https / 旧 `/ops/discover` **不**进运维 Gate
- [ ] 管理 IP / clearToken / 删当前 IP 门禁与 Flutter 一致
- [ ] 运维消息 / 收藏入口已挂到 Gate（不再是宿主侧占位 toast）
- [ ] `Podfile.lock` 可复现；跟版步骤已写入宿主文档；宿主 `pod update AutumnOpsUI`（≥0.1.21）+ `AutumnOpsCore`（≥0.1.21）；`:tag => 'ops-v0.1.21'`；`SPEC CHECKSUMS` 各机一致

---

## 6. 回滚

宿主去掉 Pod 与薄壳调用，恢复原先占位行为即可（revert 挂载提交）。
