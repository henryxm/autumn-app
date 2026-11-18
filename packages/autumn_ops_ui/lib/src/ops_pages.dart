import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ops_manage_page.dart';
import 'ops_site_io.dart';

/// Shell / host entry: multi-site list.
class AutumnOpsHome extends StatelessWidget {
  const AutumnOpsHome({super.key});

  @override
  Widget build(BuildContext context) => const OpsSitesPage();
}

/// Multi Autumn site list.
class OpsSitesPage extends StatefulWidget {
  const OpsSitesPage({super.key});

  @override
  State<OpsSitesPage> createState() => _OpsSitesPageState();
}

class _OpsSitesPageState extends State<OpsSitesPage> {
  OpsSiteStore? _store;
  List<OpsSiteEntry> _sites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final store = await openOpsSiteStore();
    final list = await store.listSites();
    if (!mounted) return;
    setState(() {
      _store = store;
      _sites = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autumn 运维')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const OpsAddSitePage(),
            ),
          );
          await _reload();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sites.isEmpty
              ? const Center(child: Text('点击右下角添加 Autumn 站点'))
              : ListView.separated(
                  itemCount: _sites.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final s = _sites[i];
                    return ListTile(
                      title: Text(s.title.isEmpty ? s.baseUrl : s.title),
                      subtitle: Text(
                        '${s.baseUrl}\n'
                        '${s.enrolled ? '已入驻' : '未入驻'}'
                        '${s.serverFingerprint != null ? ' · ${s.serverFingerprint}' : ''}',
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OpsManageSitePage(siteId: s.id),
                          ),
                        );
                        await _reload();
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _store?.removeSite(s.id);
                          await _reload();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

/// Add site: probe → enroll → manage.
class OpsAddSitePage extends StatefulWidget {
  const OpsAddSitePage({super.key});

  @override
  State<OpsAddSitePage> createState() => _OpsAddSitePageState();
}

class _OpsAddSitePageState extends State<OpsAddSitePage> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  String _status = '';
  OpsProbeOutcome? _outcome;
  /// Winning base URL from last probe (scheme resolved).
  String? _resolvedBaseUrl;
  bool _busy = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  String _effectiveBaseUrl() {
    final resolved = _resolvedBaseUrl;
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final plan = OpsEndpoint.resolve(_urlCtrl.text);
    return plan.isEmpty ? '' : plan.candidates.first;
  }

  Future<void> _probe() async {
    if (_busy) return;
    final plan = OpsEndpoint.resolve(_urlCtrl.text);
    if (plan.isEmpty) {
      setState(() {
        _status = '请填写域名或 IP';
        _outcome = null;
        _resolvedBaseUrl = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = plan.kind == OpsEndpointKind.domain
          ? '探测中（优先 https，再 http）…'
          : plan.kind == OpsEndpointKind.ip
              ? '探测中（内网/IP 使用 http）…'
              : '探测中…';
      _outcome = null;
      _resolvedBaseUrl = null;
    });
    try {
      final store = await openOpsSiteStore();
      final probeStore = store.credentialStoreFor(
        OpsSiteEntry(id: 'tmp', title: '', baseUrl: plan.candidates.first),
      );
      final hasCert = await probeStore.load() != null;
      final resolved = await OpsEndpoint.probePlan(
        plan: plan,
        store: probeStore,
        hasLocalCert: hasCert,
      );
      if (!mounted) return;
      setState(() {
        _outcome = resolved.outcome;
        _resolvedBaseUrl = resolved.baseUrl.isEmpty ? null : resolved.baseUrl;
        if (resolved.baseUrl.isNotEmpty &&
            resolved.outcome.kind != OpsProbeKind.network) {
          _urlCtrl.text = resolved.baseUrl;
        }
        final tried = resolved.tried.join(' → ');
        _status = resolved.tried.length > 1
            ? '${resolved.outcome.message}\n尝试: $tried'
            : resolved.outcome.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enrollAndOpen() async {
    if (_busy) return;
    final base = _effectiveBaseUrl();
    final secret = _secretCtrl.text.trim();
    if (base.isEmpty || secret.isEmpty) {
      setState(() => _status = '请填写地址与 OpsEnroll secret');
      return;
    }
    if (_outcome?.kind != OpsProbeKind.pending &&
        _outcome?.kind != OpsProbeKind.needReset) {
      setState(() => _status = '请先探测且站点可入驻');
      return;
    }
    setState(() {
      _busy = true;
      _status = '入驻中…';
    });
    try {
      final store = await openOpsSiteStore();
      final id = const Uuid().v4();
      final site = OpsSiteEntry(
        id: id,
        title: _titleCtrl.text.trim().isEmpty ? base : _titleCtrl.text.trim(),
        baseUrl: base,
      );
      final client = AutumnOpsClient(
        baseUrl: base,
        store: store.credentialStoreFor(site),
      );
      final enrolled = await client.enroll(secret: secret, label: 'autumn-ops');
      site.siteId = enrolled.siteId;
      site.certId = enrolled.certId;
      site.serverFingerprint = enrolled.serverFingerprint;
      site.enrolled = true;
      await store.upsertSite(site);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OpsManageSitePage(siteId: site.id),
        ),
      );
    } catch (e) {
      setState(() => _status = '入驻失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReadyAndOpen() async {
    final base = _effectiveBaseUrl();
    if (base.isEmpty) {
      setState(() => _status = '请先成功探测');
      return;
    }
    final store = await openOpsSiteStore();
    final id = const Uuid().v4();
    final site = OpsSiteEntry(
      id: id,
      title: _titleCtrl.text.trim().isEmpty ? base : _titleCtrl.text.trim(),
      baseUrl: base,
      siteId: _outcome?.result?.siteId,
      serverFingerprint: _outcome?.result?.serverFingerprint,
      enrolled: true,
    );
    final bundle = await store.credentialStoreFor(site).load();
    if (bundle != null) {
      site.certId = bundle.certId;
    }
    await store.upsertSite(site);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OpsManageSitePage(siteId: site.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEnroll = _outcome?.kind == OpsProbeKind.pending;
    final canOpenReady = _outcome?.kind == OpsProbeKind.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('添加 Autumn 站点')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '显示名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: '域名或 IP',
              hintText: 'example.com / 192.168.1.10 / https://…',
              border: OutlineInputBorder(),
              helperMaxLines: 3,
              helperText:
                  '域名：优先 https 再 http；IP（含内网）：http。已写 http(s):// 则不再自动拼接。',
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
              // Input changed — discard previous resolved winner.
              if (_resolvedBaseUrl != null || _outcome != null) {
                setState(() {
                  _resolvedBaseUrl = null;
                  _outcome = null;
                });
              }
            },
            onEditingComplete: _probe,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy ? null : _probe,
            child: const Text('探测'),
          ),
          if (canEnroll) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _secretCtrl,
              decoration: const InputDecoration(
                labelText: 'OpsEnroll secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : _enrollAndOpen,
              child: const Text('入驻并进入管理'),
            ),
          ],
          if (canOpenReady) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _busy ? null : _saveReadyAndOpen,
              child: const Text('保存并进入管理'),
            ),
          ],
          const SizedBox(height: 16),
          Text(_status),
          const SizedBox(height: 8),
          const Text(
            '丢钥：能登录 wall 则重置证书；否则 DB 清空 SECURITY_OPS_CERT_CONFIG 后重启，再复制新 OpsEnroll。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
