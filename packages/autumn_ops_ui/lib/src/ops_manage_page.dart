import 'dart:io';

import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'ops_site_io.dart';

/// Single-site advanced ops console: admin IP, gate, user IP white/black, certs.
class OpsManageSitePage extends StatefulWidget {
  const OpsManageSitePage({super.key, required this.siteId});

  final String siteId;

  @override
  State<OpsManageSitePage> createState() => _OpsManageSitePageState();
}

class _OpsManageSitePageState extends State<OpsManageSitePage> {
  OpsSiteEntry? _site;
  OpsSiteStore? _store;
  final _passCtrl = TextEditingController();
  final _clearTokenCtrl = TextEditingController();
  final _adminIpCtrl = TextEditingController();
  final _userIpCtrl = TextEditingController();
  final _blackIpCtrl = TextEditingController();

  String _status = '';
  bool _busy = false;
  bool? _adminIpEnable;
  String _currentIp = '';
  List<Map<String, dynamic>> _adminIps = [];
  List<Map<String, dynamic>> _userWhites = [];
  List<Map<String, dynamic>> _userBlacks = [];
  List<Map<String, dynamic>> _certs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _clearTokenCtrl.dispose();
    _adminIpCtrl.dispose();
    _userIpCtrl.dispose();
    _blackIpCtrl.dispose();
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

  Future<void> _refreshRemote() async {
    await _run(() async {
      final c = await _client();
      if (c == null) return;
      await c.ensureSession();
      final gate = await c.gateGet();
      final cur = await c.currentIp();
      final admin = await c.adminIpList();
      final white = await c.ipWhiteList();
      final black = await c.ipBlackList();
      final certs = await c.certList();
      setState(() {
        _adminIpEnable = gate['adminIpEnable'] == true;
        _currentIp = '${cur['ip'] ?? ''}';
        _adminIps = _asMaps(admin['list']);
        _userWhites = _asMaps(white['list']);
        _userBlacks = _asMaps(black['list']);
        _certs = _asMaps(certs['list']);
        _status =
            '已刷新 · 当前IP=$_currentIp · adminIpEnable=$_adminIpEnable';
      });
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '处理中…';
    });
    try {
      await action();
    } catch (e) {
      setState(() => _status = '失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _clearToken => _clearTokenCtrl.text.trim();

  @override
  Widget build(BuildContext context) {
    final site = _site;
    return Scaffold(
      appBar: AppBar(
        title: Text(site?.title ?? '站点管理'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _refreshRemote,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新远程状态',
          ),
        ],
      ),
      body: site == null
          ? Center(child: Text(_status))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(_status),
                const SizedBox(height: 4),
                Text(
                  'certId=${site.certId ?? '-'} fp=${site.serverFingerprint ?? '-'}\n'
                  'currentIp=$_currentIp adminIpEnable=${_adminIpEnable ?? '-'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _clearTokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'clearToken（关门禁 / 删当前 IP 时必填）',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                _sectionTitle('管理 IP（wall_ip_admin_white）'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                final r =
                                    await c!.adminIpAdd(claimCurrent: true);
                                setState(
                                    () => _status = '已认领管理 IP: ${r['ip']}');
                                await _refreshRemote();
                              }),
                      child: const Text('认领当前 IP'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final ip = _adminIpCtrl.text.trim();
                                if (ip.isEmpty) {
                                  setState(() => _status = '请填写管理 IP');
                                  return;
                                }
                                final c = await _client();
                                final r = await c!.adminIpAdd(ip: ip);
                                setState(
                                    () => _status = '已添加管理 IP: ${r['ip']}');
                                _adminIpCtrl.clear();
                                await _refreshRemote();
                              }),
                      child: const Text('添加管理 IP'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _adminIpCtrl,
                  decoration: const InputDecoration(
                    labelText: '管理 IP',
                    border: OutlineInputBorder(),
                  ),
                ),
                ..._adminIps.map(
                  (row) => ListTile(
                    dense: true,
                    title: Text('${row['ip']}'),
                    subtitle: Text('${row['tag'] ?? ''} ${row['description'] ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                await c!.adminIpRemove(
                                  '${row['ip']}',
                                  clearToken: _clearToken.isEmpty
                                      ? null
                                      : _clearToken,
                                );
                                setState(() =>
                                    _status = '已删除管理 IP: ${row['ip']}');
                                await _refreshRemote();
                              }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('管理 IP 校验开关'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                final g = await c!.gateSetAdminIpEnable(
                                  enable: true,
                                );
                                setState(() {
                                  _adminIpEnable = g['adminIpEnable'] == true;
                                  _status =
                                      'adminIpEnable=${g['adminIpEnable']}';
                                });
                                await _refreshRemote();
                              }),
                      child: const Text('开启校验'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                if (_clearToken.isEmpty) {
                                  setState(
                                      () => _status = '关闭校验须填写 clearToken');
                                  return;
                                }
                                final c = await _client();
                                final g = await c!.gateSetAdminIpEnable(
                                  enable: false,
                                  clearToken: _clearToken,
                                );
                                setState(() {
                                  _adminIpEnable = g['adminIpEnable'] == true;
                                  _status =
                                      'adminIpEnable=${g['adminIpEnable']}';
                                });
                              }),
                      child: const Text('关闭校验'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle('用户级白名单（wall_ip_white）'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                final r =
                                    await c!.ipWhiteAdd(claimCurrent: true);
                                setState(
                                    () => _status = '已加用户白名单: ${r['ip']}');
                                await _refreshRemote();
                              }),
                      child: const Text('认领到用户白名单'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final ip = _userIpCtrl.text.trim();
                                if (ip.isEmpty) {
                                  setState(() => _status = '请填写用户白名单 IP');
                                  return;
                                }
                                final c = await _client();
                                final r = await c!.ipWhiteAdd(ip: ip);
                                setState(
                                    () => _status = '已加用户白名单: ${r['ip']}');
                                _userIpCtrl.clear();
                                await _refreshRemote();
                              }),
                      child: const Text('添加用户白名单'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _userIpCtrl,
                  decoration: const InputDecoration(
                    labelText: '用户白名单 IP',
                    border: OutlineInputBorder(),
                  ),
                ),
                ..._userWhites.map(
                  (row) => ListTile(
                    dense: true,
                    title: Text('${row['ip']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                await c!.ipWhiteRemove(
                                  '${row['ip']}',
                                  clearToken: _clearToken.isEmpty
                                      ? null
                                      : _clearToken,
                                );
                                setState(() =>
                                    _status = '已删用户白名单: ${row['ip']}');
                                await _refreshRemote();
                              }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('用户级黑名单（wall_ip_black）'),
                ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            final ip = _blackIpCtrl.text.trim();
                            if (ip.isEmpty) {
                              setState(() => _status = '请填写黑名单 IP');
                              return;
                            }
                            final c = await _client();
                            final r = await c!.ipBlackAdd(ip);
                            setState(() => _status = '已加黑名单: ${r['ip']}');
                            _blackIpCtrl.clear();
                            await _refreshRemote();
                          }),
                  child: const Text('添加黑名单'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _blackIpCtrl,
                  decoration: const InputDecoration(
                    labelText: '黑名单 IP',
                    border: OutlineInputBorder(),
                  ),
                ),
                ..._userBlacks.map(
                  (row) => ListTile(
                    dense: true,
                    title: Text('${row['ip']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                await c!.ipBlackRemove('${row['ip']}');
                                setState(
                                    () => _status = '已删黑名单: ${row['ip']}');
                                await _refreshRemote();
                              }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('运维证书设备'),
                ..._certs.map(
                  (row) => ListTile(
                    dense: true,
                    title: Text('${row['label'] ?? row['certId']}'),
                    subtitle: Text(
                      'certId=${row['certId']} revoked=${row['revoked']}',
                    ),
                    trailing: (row['revoked'] == true)
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.block),
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                      final c = await _client();
                                      await c!.certRevoke('${row['certId']}');
                                      setState(() => _status =
                                          '已吊销 ${row['certId']}');
                                      await _refreshRemote();
                                    }),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('本机证书包'),
                TextField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: '分享口令',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                final out = await c!.probeOutcome(
                                  hasLocalCert: true,
                                );
                                setState(() => _status = out.message);
                              }),
                      child: const Text('探测'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final c = await _client();
                                final wrapped = await c!
                                    .exportWrapped(_passCtrl.text.trim());
                                final dir = await getTemporaryDirectory();
                                final f = File(
                                    '${dir.path}/autumn-ops-${site.id}.ops');
                                await f.writeAsString(wrapped);
                                await Share.shareXFiles(
                                  [XFile(f.path)],
                                  text: 'Autumn ops credential',
                                );
                                setState(() => _status = '已导出');
                              }),
                      child: const Text('导出分享'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                final wrapped = await _promptImport(context);
                                if (wrapped == null || wrapped.isEmpty) return;
                                final c = await _client();
                                await c!.importWrapped(
                                  wrapped,
                                  _passCtrl.text.trim(),
                                );
                                site.enrolled = true;
                                final b = await c.currentBundle();
                                if (b != null) {
                                  site.certId = b.certId;
                                  site.siteId = b.siteId;
                                  site.serverFingerprint = b.serverFingerprint;
                                }
                                await _store!.upsertSite(site);
                                setState(() => _status = '已导入');
                              }),
                      child: const Text('导入'),
                    ),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                                await _store!
                                    .credentialStoreFor(site)
                                    .clear();
                                site.enrolled = false;
                                site.certId = null;
                                await _store!.upsertSite(site);
                                setState(() => _status = '已清除本机证书');
                              }),
                      child: const Text('清除本机证书'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '安全说明：关管理IP校验 / 删除「当前访问 IP」的管理或用户白名单均须 clearToken。'
                  '用户白名单防拉黑；管理 IP 管后台门禁，二者分表。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Future<String?> _promptImport(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴口令包裹密文'),
        content: TextField(controller: ctrl, maxLines: 6),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }
}
