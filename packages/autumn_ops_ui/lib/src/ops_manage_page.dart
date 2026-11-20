import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'ops_chrome.dart';
import 'ops_payload_io.dart';
import 'ops_fused_field.dart';
import 'ops_ip_list_panel.dart';
import 'ops_jump_panel.dart';
import 'ops_pages.dart';
import 'ops_recovery_page.dart';
import 'ops_runtime_panel.dart';
import 'ops_shield_panel.dart';
import 'ops_site_io.dart';

/// 单站点运维控制台：概览 / 运行 / 管理 IP / 白名单 / 黑名单 / 证书。
class OpsManageSitePage extends StatefulWidget {
  const OpsManageSitePage({super.key, required this.siteId});

  final String siteId;

  @override
  State<OpsManageSitePage> createState() => _OpsManageSitePageState();
}

class _OpsManageSitePageState extends State<OpsManageSitePage>
    with SingleTickerProviderStateMixin {
  OpsSiteEntry? _site;
  OpsSiteStore? _store;
  late final TabController _tabs;

  final _passCtrl = TextEditingController();
  final _clearTokenCtrl = TextEditingController();
  final _issueLabelCtrl = TextEditingController(text: '新设备');

  String _status = '';
  int _busyDepth = 0;
  bool _panelBusy = false;
  bool? _adminIpEnable;
  /// 公开发现页 `/ops/discover`；旧服务端缺字段时按开启处理。
  bool? _discoverEnabled;
  /// `null` 未同步；服务端 SECURITY_OPS_CONFIG.clearToken 是否已配置（不下发明文）。
  bool? _clearTokenConfigured;
  String _currentIp = '';
  bool _currentIpInAdmin = false;
  bool _currentIpInWhite = false;
  int _activeCount = 0;
  List<Map<String, dynamic>> _certs = [];
  OpsClaimIssueResult? _lastIssue;

  /// 清除确认令牌：仅校验通过后才算就绪。
  _ClearTokenUiStatus _clearTokenStatus = _ClearTokenUiStatus.empty;
  String? _clearTokenError;
  String? _verifiedClearToken;
  bool _clearTokenSaving = false;

  bool get _busy => _busyDepth > 0 || _panelBusy;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _passCtrl.dispose();
    _clearTokenCtrl.dispose();
    _issueLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = await openOpsSiteStore();
    final list = await store.listSites();
    final site = list.cast<OpsSiteEntry?>().firstWhere(
          (e) => e?.id == widget.siteId,
          orElse: () => null,
        );
    if (!mounted) return;
    setState(() {
      _store = store;
      _site = site;
      _status = site == null ? '站点不存在' : '${site.title} · ${site.baseUrl}';
    });
    if (site != null) {
      await _refreshRemote();
    }
  }

  Future<AutumnOpsClient?> _client() async {
    final site = _site;
    final store = _store;
    if (site == null || store == null) return null;
    return AutumnOpsClient(
      baseUrl: site.baseUrl,
      store: store.credentialStoreFor(site),
    );
  }

  List<Map<String, dynamic>> _asMaps(dynamic list) {
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, true);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  String _syncStatusText() {
    final ip = _currentIp.isEmpty ? '未知' : _currentIp;
    return '已同步 · 本机访问 IP：$ip';
  }

  Future<void> _refreshRemote() async {
    await _run(() async {
      final c = await _client();
      if (c == null) return;
      await c.ensureSession();
      final gate = await c.gateGet();
      final cur = await c.currentIp();
      final certs = await c.certList();
      if (!mounted) return;
      setState(() {
        _adminIpEnable = gate['adminIpEnable'] == true;
        _discoverEnabled = gate.containsKey('discoverEnabled')
            ? gate['discoverEnabled'] == true
            : true;
        _clearTokenConfigured = gate['clearTokenConfigured'] == true;
        _currentIp = cur.ip;
        _currentIpInAdmin = cur.inAdmin;
        _currentIpInWhite = cur.inWhite;
        _certs = _asMaps(certs['list']);
        _activeCount = certs['activeCount'] is int
            ? certs['activeCount'] as int
            : _certs.where((e) => e['revoked'] != true).length;
        _status = _syncStatusText();
        if (_clearTokenConfigured == false) {
          _clearTokenStatus = _clearToken.isEmpty
              ? _ClearTokenUiStatus.serverUnset
              : _ClearTokenUiStatus.pending;
          _clearTokenError = _clearToken.isEmpty
              ? '尚未配置：填写新令牌后点右侧「保存」即可在本 App 完成配置'
              : null;
          _verifiedClearToken = null;
        } else if (_clearTokenStatus == _ClearTokenUiStatus.serverUnset) {
          _clearTokenStatus = _clearToken.isEmpty
              ? _ClearTokenUiStatus.empty
              : (_verifiedClearToken == _clearToken
                  ? _ClearTokenUiStatus.ready
                  : _ClearTokenUiStatus.pending);
          _clearTokenError = null;
        }
      });
    });
  }

  /// 可重入：内部再调 [_refreshRemote]/[_run] 不会被忙锁直接吞掉。
  /// 状态条文案不写「处理中…」，忙碌仅由顶部指示器表达，避免成功后卡死文案。
  Future<void> _run(Future<void> Function() action) async {
    _busyDepth++;
    if (mounted) setState(() {});
    try {
      await action();
    } catch (e) {
      final msg = OpsErrorMessage.display(e);
      if (mounted) setState(() => _status = msg);
      _toast(OpsErrorMessage.of(e));
    } finally {
      _busyDepth = _busyDepth > 0 ? _busyDepth - 1 : 0;
      if (mounted) setState(() {});
    }
  }

  void _setPanelBusy(bool value) {
    if (_panelBusy == value) return;
    setState(() => _panelBusy = value);
  }

  String get _clearToken => _clearTokenCtrl.text.trim();
  bool get _hasVerifiedClearToken =>
      _verifiedClearToken != null &&
      _verifiedClearToken!.isNotEmpty &&
      _verifiedClearToken == _clearToken &&
      _clearTokenStatus == _ClearTokenUiStatus.ready;

  void _onClearTokenEdited(String _) {
    final text = _clearToken;
    setState(() {
      if (text.isEmpty) {
        _clearTokenStatus = _clearTokenConfigured == false
            ? _ClearTokenUiStatus.serverUnset
            : _ClearTokenUiStatus.empty;
        _clearTokenError = _clearTokenConfigured == false
            ? '尚未配置：填写新令牌后点右侧「保存」即可在本 App 完成配置'
            : null;
        // 保留 _verifiedClearToken 作「修改」时的旧令牌参考，仅在清空输入时不强制清掉已缓存旧值
        if (_clearTokenConfigured != true) {
          _verifiedClearToken = null;
        }
      } else if (_verifiedClearToken != null && text == _verifiedClearToken) {
        _clearTokenStatus = _ClearTokenUiStatus.ready;
        _clearTokenError = null;
      } else {
        _clearTokenStatus = _ClearTokenUiStatus.pending;
        _clearTokenError = null;
      }
    });
  }

  Future<String?> _promptOldClearToken() async {
    // 令牌输入框的 controller 由弹窗 State 持有：showDialog 的 Future 在 pop 时
    // 即完成，但路由退场动画期间 TextField 仍挂在树上；外层立刻 dispose 会触发
    // InheritedElement `_dependents.isEmpty` 红屏。
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const _OpsSecureTokenDialog(
        title: '验证原令牌',
        reason: '修改清除确认令牌须先验证原令牌。',
        fieldLabel: '原清除确认令牌',
        confirmLabel: '继续',
      ),
    );
    final old = result?.trim() ?? '';
    if (old.isEmpty) return null;
    final check = OpsValidators.clearToken(old);
    if (!check.ok) {
      _toast(check.error!);
      return null;
    }
    return old;
  }

  Future<void> _markClearTokenReady(String token) async {
    if (!mounted) return;
    setState(() {
      _verifiedClearToken = token;
      _clearTokenError = null;
      _clearTokenStatus = _ClearTokenUiStatus.saved;
      _clearTokenSaving = false;
      _clearTokenConfigured = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (_clearToken == token && _verifiedClearToken == token) {
      setState(() => _clearTokenStatus = _ClearTokenUiStatus.ready);
    }
  }

  Future<void> _saveClearToken() async {
    final token = _clearToken;
    final check = OpsValidators.clearToken(token);
    if (!check.ok) {
      setState(() {
        _clearTokenStatus = _ClearTokenUiStatus.error;
        _clearTokenError = check.error;
      });
      return;
    }

    final configuring = _clearTokenConfigured != true;
    final modifying = !configuring &&
        (_verifiedClearToken == null || _verifiedClearToken != token);

    setState(() => _clearTokenSaving = true);
    try {
      final c = await _client();
      await c!.ensureSession();

      if (configuring) {
        await c.gateSetClearToken(token);
        await _markClearTokenReady(token);
        _toast('已配置清除确认令牌');
        return;
      }

      if (modifying) {
        var old = _verifiedClearToken;
        if (old == null || old.isEmpty || old == token) {
          old = await _promptOldClearToken();
          if (old == null) {
            if (mounted) setState(() => _clearTokenSaving = false);
            return;
          }
        }
        await c.gateSetClearToken(token, oldClearToken: old);
        await _markClearTokenReady(token);
        _toast('已更新清除确认令牌');
        return;
      }

      // 已配置且内容与已校验令牌一致：再核对一次
      await c.gateVerifyClearToken(token);
      await _markClearTokenReady(token);
    } catch (e) {
      if (!mounted) return;
      final msg = OpsErrorMessage.of(e);
      setState(() {
        _clearTokenSaving = false;
        _clearTokenError = msg;
        _clearTokenStatus = msg.contains('尚未配置清除确认令牌')
            ? _ClearTokenUiStatus.serverUnset
            : _ClearTokenUiStatus.error;
        if (msg.contains('尚未配置清除确认令牌')) {
          _clearTokenConfigured = false;
        }
      });
    }
  }

  void _showClearTokenError() {
    final msg = _clearTokenError;
    if (msg == null || msg.isEmpty) return;
    final unset = _clearTokenStatus == _ClearTokenUiStatus.serverUnset;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unset ? '尚未配置令牌' : '操作失败'),
        content: Text(msg, style: const TextStyle(height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  }

  void _resetClearToken() {
    _clearTokenCtrl.clear();
    setState(() {
      _clearTokenStatus = _clearTokenConfigured == false
          ? _ClearTokenUiStatus.serverUnset
          : _ClearTokenUiStatus.empty;
      _clearTokenError = _clearTokenConfigured == false
          ? '尚未配置：填写新令牌后点右侧「保存」即可在本 App 完成配置'
          : null;
    });
  }

  /// 解析清除确认令牌：已校验就绪则直接用；否则弹窗填写并校验。
  Future<String?> _resolveClearToken({required String reason}) async {
    if (_clearTokenConfigured != true) {
      _toast('请先在概览页配置清除确认令牌');
      return null;
    }
    if (_hasVerifiedClearToken) return _verifiedClearToken;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _OpsSecureTokenDialog(
        title: '清除确认令牌',
        reason: reason,
        fieldLabel: '请输入清除确认令牌',
        fieldHelper: '在系统加固 / 安全配置中查看',
        confirmLabel: '校验并继续',
        initialText: _clearToken,
      ),
    );
    final token = result?.trim() ?? '';
    if (token.isEmpty) return null;
    final check = OpsValidators.clearToken(token);
    if (!check.ok) {
      _toast(check.error!);
      return null;
    }

    try {
      final c = await _client();
      await c!.ensureSession();
      await c.gateVerifyClearToken(token);
      if (!mounted) return token;
      _clearTokenCtrl.text = token;
      setState(() {
        _verifiedClearToken = token;
        _clearTokenError = null;
        _clearTokenStatus = _ClearTokenUiStatus.ready;
      });
      return token;
    } catch (e) {
      if (!mounted) return null;
      final msg = OpsErrorMessage.of(e);
      setState(() {
        _clearTokenCtrl.text = token;
        _verifiedClearToken = null;
        _clearTokenStatus = _ClearTokenUiStatus.error;
        _clearTokenError = msg;
      });
      _toast(msg);
      return null;
    }
  }

  Future<void> _enableAdminIpGate() async {
    await _run(() async {
      final c = await _client();
      final g = await c!.gateSetAdminIpEnable(enable: true);
      setState(() => _adminIpEnable = g['adminIpEnable'] == true);
      _toast('已开启管理 IP 校验');
    });
  }

  Future<void> _setDiscoverEnabled(bool enable) async {
        if (!enable) {
      if (!await _confirm(
        '关闭站点发现页',
        '关闭后，浏览器访问本站发现页将如同不存在（404），避免被探测；'
            '不影响 App 内探测与管理。可随时在此重新打开。确定关闭？',
      )) {
        return;
      }
    }
    await _run(() async {
      final c = await _client();
      final g = await c!.gateSetDiscoverEnabled(enable: enable);
      if (!mounted) return;
      setState(() {
        _discoverEnabled = g.containsKey('discoverEnabled')
            ? g['discoverEnabled'] == true
            : enable;
      });
      _toast(enable ? '已打开站点发现页' : '已关闭站点发现页');
    });
  }

  Future<void> _disableAdminIpGate() async {
    if (_clearTokenConfigured == false) {
      _toast('请先在下方配置清除确认令牌');
      return;
    }
    if (!await _confirm(
      '关闭管理 IP 校验',
      '关闭后不再校验「管理 IP」名单：任意来源 IP 只要拿到超管账号，即可进入后台与运维接口。'
          '管理 IP 列表仍会保留，但暂时不生效。仅在确认环境安全时关闭。确定？',
    )) {
      return;
    }
    final token = await _resolveClearToken(
      reason: '关闭管理 IP 校验后仅依赖超管账号，须提供清除确认令牌。',
    );
    if (token == null || token.isEmpty) {
      // 等令牌弹窗路由卸完再 toast，避免与退场动画叠 Inherited 卸载。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toast('已取消：需要清除确认令牌');
      });
      return;
    }
    await _run(() async {
      final c = await _client();
      final g = await c!.gateSetAdminIpEnable(
        enable: false,
        clearToken: token,
      );
      setState(() => _adminIpEnable = g['adminIpEnable'] == true);
      _toast('已关闭管理 IP 校验');
    });
  }

  Future<void> _openRecovery() async {
    final site = _site;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OpsRecoveryPage(
          siteTitle: site?.title,
          baseUrl: site?.baseUrl,
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required String body, required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            Text(body, style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = _site;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(site?.title ?? '站点管理'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _goSiteList,
            icon: const OpsSitesListIcon(size: 22),
            tooltip: '站点列表',
          ),
        ],
        bottom: site == null
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(text: '概览'),
                  Tab(text: '运行'),
                  Tab(text: '管理IP'),
                  Tab(text: '白名单'),
                  Tab(text: '黑名单'),
                  Tab(text: '盾牌'),
                  Tab(text: '跳转'),
                  Tab(text: '证书'),
                ],
              ),
      ),
      body: site == null
          ? Center(child: Text(_status))
          : Column(
              children: [
                // 顶栏状态条跟主题 surface，勿用 highest 卡片灰（嵌入宿主如 XSVideo 时更协调）
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _busy && _status.isEmpty
                                ? '正在连接…'
                                : (_busy ? '处理中 · $_status' : _status),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_busy) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildOverview(site),
                      _buildRuntime(),
                      _buildAdminIp(),
                      _buildIpWhite(),
                      _buildIpBlack(),
                      _buildShield(),
                      _buildJump(),
                      _buildCerts(site),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverview(OpsSiteEntry site) {
    final gateOn = _adminIpEnable == true;
    final discoverOn = _discoverEnabled != false;
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refreshRemote,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: '站点信息',
          body: '核对地址与证书指纹，确认连到正确的 Autumn 实例。',
          children: [
            _kv('站点地址', site.baseUrl),
            _kv('本机访问 IP', _currentIp.isEmpty ? '未知' : _currentIp),
            _kv(
              '本机证书标识',
              site.certId == null || site.certId!.isEmpty ? '无' : site.certId!,
            ),
            _kv('服务端指纹', site.serverFingerprint ?? '-'),
            _kv('有效设备数', '$_activeCount'),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '站点发现页',
          body: discoverOn
              ? '已打开：浏览器可访问发现页，扫码或点开链接即可引导安装运维客户端（如超然信）并添加本站。证书绑定成功后会自动关闭。'
              : '已关闭：浏览器访问发现页将如同不存在（404），避免被探测；不影响本 App 内探测与运维。',
          children: [
            Row(
              children: [
                Chip(
                  label: Text(discoverOn ? '发现已开' : '发现已关'),
                  backgroundColor: discoverOn
                      ? scheme.secondaryContainer.withValues(alpha: 0.7)
                      : scheme.errorContainer.withValues(alpha: 0.45),
                ),
                const Spacer(),
                if (discoverOn)
                  OutlinedButton(
                    onPressed:
                        _busy ? null : () => _setDiscoverEnabled(false),
                    child: const Text('关闭'),
                  )
                else
                  FilledButton(
                    onPressed:
                        _busy ? null : () => _setDiscoverEnabled(true),
                    child: const Text('打开'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '管理 IP 校验（门禁）',
          body: gateOn
              ? '已开启：进入后台与运维接口时，除超管账号外，客户端 IP 还必须在「管理 IP」名单中。'
              : '已关闭：仅校验超管账号，不再核对管理 IP。账号泄露时攻击者可从任意 IP 进入后台。',
          children: [
            Row(
              children: [
                Chip(
                  label: Text(gateOn ? '已开' : '已关'),
                  backgroundColor: gateOn
                      ? scheme.secondaryContainer.withValues(alpha: 0.7)
                      : scheme.errorContainer.withValues(alpha: 0.45),
                ),
                const Spacer(),
                if (gateOn)
                  OutlinedButton(
                    onPressed: _busy ? null : _disableAdminIpGate,
                    child: const Text('关闭'),
                  )
                else
                  FilledButton(
                    onPressed: _busy ? null : _enableAdminIpGate,
                    child: const Text('开启'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildClearTokenCard(),
        if (!_currentIpInAdmin) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                      final c = await _client();
                      final r = await c!.adminIpAdd(claimCurrent: true);
                      _toast('已认领管理 IP：${r['ip']}');
                      await _refreshRemote();
                    }),
            icon: const Icon(Icons.my_location),
            label: const Text('认领当前 IP 为管理 IP'),
          ),
        ],
        const SizedBox(height: 12),
        _sectionCard(
          title: '分享管理入口',
          body: discoverOn
              ? '生成发现链接。他人用运维客户端（如超然信）扫码或点开后可自动探测本站运维能力。'
              : '发现页当前已关闭。仍可复制链接供运维客户端打开；浏览器打开将得到 404。',
          children: [
            SelectableText(
              AutumnOpsDiscover.shareUrlForBase(site.baseUrl),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _copyDiscoverLink(site),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('复制链接'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _shareDiscoverLink(site),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('分享'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _openRecovery,
          icon: const Icon(Icons.help_outline),
          label: const Text('丢钥 / 无法入驻时如何恢复'),
        ),
      ],
      ),
    );
  }

  Widget _buildRuntime() {
    return OpsRuntimePanel(
      busy: _busy,
      onBusyChanged: _setPanelBusy,
      onToast: _toast,
      loadSnapshot: () async {
        final c = await _client();
        if (c == null) {
          throw StateError('站点未就绪');
        }
        await c.ensureSession();
        return c.runtimeSnapshot();
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }

  Widget _clearTokenStatusChip(ColorScheme scheme) {
    switch (_clearTokenStatus) {
      case _ClearTokenUiStatus.serverUnset:
        return InkWell(
          onTap: _showClearTokenError,
          borderRadius: BorderRadius.circular(16),
          child: Chip(
            label: const Text('未配置'),
            avatar: Icon(Icons.info_outline, size: 14, color: scheme.onErrorContainer),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelStyle: TextStyle(fontSize: 11, color: scheme.onErrorContainer),
            backgroundColor: scheme.errorContainer.withValues(alpha: 0.55),
            side: BorderSide.none,
          ),
        );
      case _ClearTokenUiStatus.empty:
        return Chip(
          label: const Text('未填写'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          labelStyle: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          backgroundColor: scheme.surfaceContainerHighest,
          side: BorderSide.none,
        );
      case _ClearTokenUiStatus.pending:
        return Chip(
          label: const Text('待保存'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          labelStyle: TextStyle(fontSize: 11, color: scheme.onTertiaryContainer),
          backgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.65),
          side: BorderSide.none,
        );
      case _ClearTokenUiStatus.saved:
        return Chip(
          label: const Text('已保存'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          labelStyle: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer),
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.8),
          side: BorderSide.none,
        );
      case _ClearTokenUiStatus.ready:
        return Chip(
          label: const Text('已就绪'),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          labelStyle: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer),
          backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.7),
          side: BorderSide.none,
        );
      case _ClearTokenUiStatus.error:
        return InkWell(
          onTap: _showClearTokenError,
          borderRadius: BorderRadius.circular(16),
          child: Chip(
            label: const Text('错误'),
            avatar: Icon(Icons.error_outline, size: 14, color: scheme.onErrorContainer),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelStyle: TextStyle(fontSize: 11, color: scheme.onErrorContainer),
            backgroundColor: scheme.errorContainer.withValues(alpha: 0.75),
            side: BorderSide.none,
          ),
        );
    }
  }

  Widget _buildClearTokenInputBar(ColorScheme scheme) {
    final configuring = _clearTokenConfigured != true;
    final canSave = _clearToken.isNotEmpty && !_clearTokenSaving && !_busy;
    final actionLabel = configuring
        ? '配置'
        : (_verifiedClearToken != null && _verifiedClearToken != _clearToken ? '修改' : '保存');
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _clearTokenCtrl,
                obscureText: true,
                enabled: !_clearTokenSaving,
                textInputAction: TextInputAction.done,
                onChanged: _onClearTokenEdited,
                onSubmitted: (_) {
                  if (canSave) _saveClearToken();
                },
                style: const TextStyle(fontSize: 15, height: 1.2),
                decoration: InputDecoration(
                  hintText: configuring ? '设置新的清除确认令牌' : '输入令牌后保存校验，或修改后保存',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  suffixIcon: _clearToken.isNotEmpty
                      ? IconButton(
                          tooltip: '清空',
                          onPressed: _clearTokenSaving ? null : _resetClearToken,
                          icon: const Icon(Icons.clear, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            Container(width: 1, height: double.infinity, color: scheme.outlineVariant),
            SizedBox(
              height: double.infinity,
              child: TextButton(
                onPressed: canSave ? _saveClearToken : null,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const RoundedRectangleBorder(),
                ),
                child: _clearTokenSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 独立的安全能力：清除确认令牌（不挂在 IP 列表下）。
  Widget _buildClearTokenCard() {
    final scheme = Theme.of(context).colorScheme;
    final configuring = _clearTokenConfigured != true;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('清除确认令牌', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                _clearTokenStatusChip(scheme),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              configuring
                  ? '尚未配置时，关闭门禁、删除当前访问 IP 等危险操作无法执行。'
                      '可在此直接设置令牌（需已入驻运维证书）；配置后也可随时修改。'
                  : '用于关闭管理 IP 校验、删除「当前访问 IP」等危险操作的二次确认。'
                      '右侧「保存」可校验；改成新值后点「修改」须验证原令牌。',
              style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
            ),
            if ((_clearTokenStatus == _ClearTokenUiStatus.error ||
                    _clearTokenStatus == _ClearTokenUiStatus.serverUnset) &&
                (_clearTokenError ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: _showClearTokenError,
                child: Text(
                  _clearTokenError!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: _clearTokenStatus == _ClearTokenUiStatus.serverUnset
                        ? scheme.onSurfaceVariant
                        : scheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildClearTokenInputBar(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminIp() {
    return OpsIpListPanel(
      title: '管理 IP',
      description: '控制谁可以打开后台登录页（进门白名单）。与「用户白名单 / 黑名单」分表，互不影响。',
      statusMode: OpsIpStatusMode.forbidden,
      currentIp: _currentIp,
      claimCurrentHidden: _currentIpInAdmin,
      resolveClearToken: _resolveClearToken,
      busy: _busy,
      onBusyChanged: _setPanelBusy,
      onToast: _toast,
      loadPage: ({required int page, required int limit}) async {
        final c = await _client();
        await c!.ensureSession();
        return c.adminIpList(page: page, limit: limit);
      },
      onMembershipMayChange: () {
        _refreshRemote();
      },
      onAdd: ({String? ip, bool claimCurrent = false}) async {
        final c = await _client();
        final r = await c!.adminIpAdd(ip: ip, claimCurrent: claimCurrent);
        return '${r['ip'] ?? ip ?? ''}';
      },
      onRemove: (ip, {String? clearToken}) async {
        final c = await _client();
        await c!.adminIpRemove(ip, clearToken: clearToken);
      },
      onToggle: (ip, {required bool enable}) async {
        final c = await _client();
        await c!.adminIpSetForbidden(ip, forbidden: !enable);
      },
    );
  }

  Widget _buildIpWhite() {
    return OpsIpListPanel(
      title: '用户白名单',
      description: '防火墙白名单：列入后可降低被误拉黑风险。与「管理 IP」不是同一张表。',
      statusMode: OpsIpStatusMode.forbidden,
      currentIp: _currentIp,
      claimCurrentHidden: _currentIpInAdmin || _currentIpInWhite,
      resolveClearToken: _resolveClearToken,
      busy: _busy,
      onBusyChanged: _setPanelBusy,
      onToast: _toast,
      onMembershipMayChange: () {
        _refreshRemote();
      },
      ipInputHint: '请输入白名单 IP',
      loadPage: ({required int page, required int limit}) async {
        final c = await _client();
        await c!.ensureSession();
        return c.ipWhiteList(page: page, limit: limit);
      },
      onAdd: ({String? ip, bool claimCurrent = false}) async {
        final c = await _client();
        final r = await c!.ipWhiteAdd(ip: ip, claimCurrent: claimCurrent);
        return '${r['ip'] ?? ip ?? ''}';
      },
      onRemove: (ip, {String? clearToken}) async {
        final c = await _client();
        await c!.ipWhiteRemove(ip, clearToken: clearToken);
      },
      onToggle: (ip, {required bool enable}) async {
        final c = await _client();
        await c!.ipWhiteSetForbidden(ip, forbidden: !enable);
      },
    );
  }

  Widget _buildShield() {
    return OpsShieldPanel(
      busy: _busy,
      onBusyChanged: _setPanelBusy,
      onToast: _toast,
      client: _client,
    );
  }

  Widget _buildJump() {
    return OpsJumpPanel(
      busy: _busy,
      onBusyChanged: _setPanelBusy,
      onToast: _toast,
      client: _client,
    );
  }

  Widget _buildIpBlack() {
    return OpsIpListPanel(
      title: '用户黑名单',
      description:
          '防火墙黑名单：生效后直接拒绝访问。停用可保留记录而不再拦截。'
          '「0.0.0.0」不是普通 IP，而是服务端存放自动拉黑阈值的策略行（列表已隐藏）；请用上方阈值修改。',
      statusMode: OpsIpStatusMode.available,
      currentIp: _currentIp,
      busy: _busy,
      onBusyChanged: _setPanelBusy,
      onToast: _toast,
      allowClaimCurrent: false,
      requireClearTokenForCurrent: false,
      ipInputHint: '请输入黑名单 IP（勿填 0.0.0.0）',
      header: _IpBlackFirewallCountBar(
        busy: _busy,
        onBusyChanged: _setPanelBusy,
        onToast: _toast,
        client: _client,
      ),
      loadPage: ({required int page, required int limit}) async {
        final c = await _client();
        await c!.ensureSession();
        return c.ipBlackList(page: page, limit: limit);
      },
      onAdd: ({String? ip, bool claimCurrent = false}) async {
        final c = await _client();
        final target = (ip ?? '').trim();
        final check = OpsValidators.wallIp(target, rejectPolicyBlackIp: true);
        if (!check.ok) {
          throw StateError(check.error!);
        }
        final r = await c!.ipBlackAdd(target);
        return '${r['ip'] ?? target}';
      },
      onRemove: (ip, {String? clearToken}) async {
        final c = await _client();
        await c!.ipBlackRemove(ip);
      },
      onToggle: (ip, {required bool enable}) async {
        final c = await _client();
        // wall：available=0 生效，1 停用
        await c!.ipBlackSetAvailable(ip, available: enable ? 0 : 1);
      },
    );
  }

  /// 左侧输入 + 右侧动作，与 IP / 令牌 / 添加站点同一视觉语言。
  Widget _fusedFieldAction({
    required TextEditingController controller,
    required String hintText,
    required String actionLabel,
    required VoidCallback? onAction,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return OpsFusedFieldAction(
      controller: controller,
      hintText: hintText,
      actionLabel: actionLabel,
      onAction: onAction,
      enabled: !_busy,
      obscure: obscure,
      keyboardType: keyboardType,
    );
  }

  Future<void> _issueClaimCode() async {
    final labelCheck = OpsValidators.deviceLabel(_issueLabelCtrl.text);
    if (!labelCheck.ok) {
      _toast(labelCheck.error!);
      return;
    }
    await _run(() async {
      final c = await _client();
      final issued = await c!.certIssue(
        label: _issueLabelCtrl.text.trim().isEmpty ? '新设备' : _issueLabelCtrl.text.trim(),
      );
      setState(() => _lastIssue = issued);
      _toast('已签发认领码（约 30 分钟有效）');
    });
  }

  void _goSiteList() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OpsSitesPage()),
      (route) => route.isFirst,
    );
  }

  Future<void> _copyDiscoverLink(OpsSiteEntry site) async {
    final url = AutumnOpsDiscover.shareUrlForBase(site.baseUrl);
    if (url.isEmpty) {
      _toast('无法生成链接');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    _toast('已复制发现链接');
  }

  Future<void> _shareDiscoverLink(OpsSiteEntry site) async {
    final url = AutumnOpsDiscover.shareUrlForBase(site.baseUrl);
    if (url.isEmpty) {
      _toast('无法生成链接');
      return;
    }
    await Share.share(
      'Autumn 运维发现入口（请用运维客户端打开，如超然信 https://chaoran.xin/）：\n$url',
      subject: 'Autumn 运维',
    );
  }

  Future<void> _shareToChat(OpsSiteEntry site) async {
    final passCheck = OpsValidators.sharePassphrase(_passCtrl.text);
    if (!passCheck.ok) {
      _toast(passCheck.error!);
      return;
    }
    if (AutumnOpsShareHooks.toChat == null) {
      _toast('当前 App 未接入「分享到聊天」');
      return;
    }
    await _run(() async {
      final c = await _client();
      if (!mounted) {
        return;
      }
      final ok = await shareAutumnOpsToChat(
        context: context,
        client: c!,
        passphrase: _passCtrl.text.trim(),
        site: site,
      );
      if (!mounted) {
        return;
      }
      if (ok) {
        _toast('已打开分享到聊天');
      } else {
        _toast('未完成分享');
      }
    });
  }

  Future<void> _exportCredentialFile(OpsSiteEntry site) async {
    final passCheck = OpsValidators.sharePassphrase(_passCtrl.text);
    if (!passCheck.ok) {
      _toast(passCheck.error!);
      return;
    }
    await _run(() async {
      final c = await _client();
      await exportAutumnOpsCredentialFile(
        client: c!,
        passphrase: _passCtrl.text.trim(),
        site: site,
      );
      _toast('已导出运维凭证文件');
    });
  }

  Future<void> _importCredentialFile(OpsSiteEntry site) async {
    final passCheck = OpsValidators.sharePassphrase(_passCtrl.text);
    if (!passCheck.ok) {
      _toast(passCheck.error!);
      return;
    }
    final picked = await pickAutumnOpsCredentialFile();
    if (picked.cancelled) return;
    if (!picked.ok) {
      _toast(picked.error ?? '选择凭证失败');
      return;
    }
    await _run(() async {
      final pass = _passCtrl.text.trim();
      final c = await _client();
      await c!.importWrapped(picked.payload!.wrapped, pass);
      site.enrolled = true;
      final b = await c.currentBundle();
      if (b != null) {
        site.certId = b.certId;
        site.siteId = b.siteId;
        site.serverFingerprint = b.serverFingerprint;
      }
      await _store!.upsertSite(site);
      _toast('已从 ${picked.displayName} 覆盖导入');
      await _refreshRemote();
    });
  }

  Widget _buildCerts(OpsSiteEntry site) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refreshRemote,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: '已登记设备',
          body: '当前有效 $_activeCount 台。列表中的「标签」来自签发时填写的设备名；吊销后该设备无法再建运维会话。',
          children: [
            if (_certs.isEmpty)
              Text('暂无设备', style: TextStyle(color: scheme.onSurfaceVariant))
            else
              ..._certs.map((row) {
                final revoked = row['revoked'] == true;
                final self = row['self'] == true ||
                    (site.certId != null && site.certId == '${row['certId']}');
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: scheme.surface.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text('${row['label'] ?? row['certId']}'),
                    subtitle: Text(
                      '${self ? '本机 · ' : '其他设备 · '}'
                      '证书标识 ${row['certId']}'
                      '${revoked ? ' · 已吊销' : ''}',
                    ),
                    trailing: revoked
                        ? const Chip(label: Text('已吊销'), visualDensity: VisualDensity.compact)
                        : IconButton(
                            icon: const Icon(Icons.block),
                            tooltip: '吊销',
                            onPressed: _busy
                                ? null
                                : () async {
                                    final id = '${row['certId']}';
                                    final lastOne = _activeCount <= 1;
                                    final ok = await _confirm(
                                      lastOne ? '吊销最后一张有效证书' : '吊销证书',
                                      lastOne
                                          ? '这是最后一张有效证。吊销后所有运维设备将无法登录证书通道，只能通过防火墙/数据库重置恢复。确定吊销？'
                                          : '确定吊销 $id？该设备将无法再建运维会话。',
                                    );
                                    if (!ok) return;
                                    await _run(() async {
                                      final c = await _client();
                                      final r = await c!.certRevoke(id);
                                      if (r.lastCert) {
                                        _toast('已吊销最后一张有效证');
                                        await _store!.credentialStoreFor(site).clear();
                                        site.enrolled = false;
                                        site.certId = null;
                                        await _store!.upsertSite(site);
                                        if (mounted) await _openRecovery();
                                      } else {
                                        _toast('已吊销');
                                        await _refreshRemote();
                                      }
                                    });
                                  },
                          ),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '① 签发认领码（给同事 / 新设备）',
          body: '新设备会自建密钥，可单独吊销。流程：本页签发 → 把认领码发给对方 →'
              '对方首页「+」探测同一地址 → 选「认领码」粘贴。约 30 分钟有效，一次性。'
              '「设备标签」只是备注名，不是认领码。',
          children: [
            _fusedFieldAction(
              controller: _issueLabelCtrl,
              hintText: '设备标签（选填，如：办公室平板）',
              actionLabel: '签发认领码',
              onAction: _busy ? null : _issueClaimCode,
            ),
            if (_lastIssue != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '认领码（仅显示一次）'
                      '${(_lastIssue!.label ?? '').isNotEmpty ? ' · ${_lastIssue!.label}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _lastIssue!.claimSecret,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: _lastIssue!.claimSecret),
                            );
                            _toast('已复制认领码');
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('复制'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Share.share(
                              '【Autumn 运维 · 认领码】约 30 分钟有效\n'
                              '1. 打开 Autumn 运维 → 右上角「+」\n'
                              '2. 填写站点：${site.baseUrl}\n'
                              '3. 点「探测」→ 选「认领码」\n'
                              '4. 粘贴认领码：${_lastIssue!.claimSecret}\n'
                              '（这是文字认领码，不是运维密钥消息）',
                            );
                          },
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text('分享步骤+认领码'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: '② 分享运维密钥（同证）',
          body: '用分享口令包裹本机运维密钥后发到宿主聊天会话（消息类型 AutumnOps，同一 certId）。'
              '对端点开运维卡并输入同一口令即可导入。口令不当场写入消息。'
              '给同事单独一台机请用上方① 认领码。',
          children: [
            _fusedFieldAction(
              controller: _passCtrl,
              hintText: '分享口令（加密密钥，导入时再输入）',
              actionLabel: '分享到聊天',
              obscure: true,
              onAction: _busy ? null : () => _shareToChat(site),
            ),
            const SizedBox(height: 8),
            Text(
              '也可导出本机凭证文件（非聊天入口），或选文件覆盖导入到本站点。',
              style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _exportCredentialFile(site),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('导出运维凭证文件'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _importCredentialFile(site),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('选凭证文件覆盖到本站点'),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!await _confirm(
                          '清除本机证书',
                          '仅删除本机私钥包，不会吊销服务端登记。若这是唯一设备且无其它凭证，需防火墙重置才能再入驻。确定？',
                        )) {
                          return;
                        }
                        await _run(() async {
                          await _store!.credentialStoreFor(site).clear();
                          site.enrolled = false;
                          site.certId = null;
                          await _store!.upsertSite(site);
                          _toast('已清除本机证书');
                          if (mounted) await _openRecovery();
                        });
                      },
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('清除本机证书'),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

enum _ClearTokenUiStatus {
  /// 服务端 SECURITY_OPS_CONFIG.clearToken 为空：无法校验、也无法做依赖令牌的危险操作。
  serverUnset,
  empty,
  pending,
  saved,
  ready,
  error,
}

/// 清除确认令牌输入弹窗：controller 由本 State 持有，在路由真正卸载时再 dispose，
/// 避免 showDialog Future 返回后外层立刻 dispose 踩 `_dependents.isEmpty`。
class _OpsSecureTokenDialog extends StatefulWidget {
  const _OpsSecureTokenDialog({
    required this.title,
    required this.reason,
    required this.fieldLabel,
    required this.confirmLabel,
    this.fieldHelper,
    this.initialText = '',
  });

  final String title;
  final String reason;
  final String fieldLabel;
  final String? fieldHelper;
  final String confirmLabel;
  final String initialText;

  @override
  State<_OpsSecureTokenDialog> createState() => _OpsSecureTokenDialogState();
}

class _OpsSecureTokenDialogState extends State<_OpsSecureTokenDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pop([String? value]) {
    // 先卸焦点再 pop，避免 EditableText 仍挂在即将卸载的 Inherited 上。
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, value);
  }

  void _submit() => _pop(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.reason,
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              helperText: widget.fieldHelper,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// 黑名单 Tab 顶部：自动拉黑阈值（同源 wall「黑名单阈值」/ 策略行 0.0.0.0）。
class _IpBlackFirewallCountBar extends StatefulWidget {
  const _IpBlackFirewallCountBar({
    required this.busy,
    required this.onBusyChanged,
    required this.onToast,
    required this.client,
  });

  final bool busy;
  final ValueChanged<bool> onBusyChanged;
  final ValueChanged<String> onToast;
  final Future<AutumnOpsClient?> Function() client;

  @override
  State<_IpBlackFirewallCountBar> createState() => _IpBlackFirewallCountBarState();
}

class _IpBlackFirewallCountBarState extends State<_IpBlackFirewallCountBar> {
  final _ctrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await widget.client();
      await c!.ensureSession();
      final n = await c.ipBlackFirewallCount();
      if (!mounted) return;
      _ctrl.text = '$n';
    } catch (e) {
      if (mounted) widget.onToast(OpsErrorMessage.of(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (widget.busy || _loading) return;
    final raw = _ctrl.text.trim();
    final n = int.tryParse(raw);
    if (n == null || n < 500) {
      widget.onToast('阈值须为不小于 500 的整数');
      return;
    }
    widget.onBusyChanged(true);
    try {
      final c = await widget.client();
      final saved = await c!.ipBlackSetFirewallCount(n);
      if (!mounted) return;
      _ctrl.text = '$saved';
      widget.onToast('已保存黑名单阈值：$saved 次/刷新周期');
    } catch (e) {
      widget.onToast(OpsErrorMessage.of(e));
    } finally {
      widget.onBusyChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自动拉黑阈值（策略 0.0.0.0）',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            '同一刷新周期内访问超过该次数将自动加入黑名单。最小值 500。',
            style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          OpsFusedFieldAction(
            controller: _ctrl,
            hintText: '例如 1000',
            actionLabel: _loading ? '…' : '保存',
            enabled: !widget.busy && !_loading,
            keyboardType: TextInputType.number,
            onAction: widget.busy || _loading ? null : _save,
          ),
        ],
      ),
    );
  }
}
