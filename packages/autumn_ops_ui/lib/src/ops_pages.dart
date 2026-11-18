import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ops_manage_page.dart';
import 'ops_recovery_page.dart';
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
      appBar: AppBar(
        title: const Text('Autumn 运维'),
        actions: [
          IconButton(
            tooltip: '添加站点',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const OpsAddSitePage(),
                ),
              );
              await _reload();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sites.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '还没有站点。\n'
                      '点击右上角「+」：首次入驻、认领码入驻，或导入他机导出的证书备份。',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: _sites.length,
                  itemBuilder: (ctx, i) {
                    final s = _sites[i];
                    final scheme = Theme.of(context).colorScheme;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          s.title.isEmpty ? s.baseUrl : s.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${s.baseUrl}\n'
                            '${s.enrolled ? '本机已入驻' : '本机未入驻'}'
                            '${s.serverFingerprint != null ? ' · 指纹 ${s.serverFingerprint}' : ''}',
                            style: TextStyle(height: 1.35, color: scheme.onSurfaceVariant),
                          ),
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
                          tooltip: '从本机移除',
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('删除站点'),
                                content: Text(
                                  '从本机列表移除「${s.title.isEmpty ? s.baseUrl : s.title}」？'
                                  '不会自动吊销服务端证书。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await _store?.removeSite(s.id);
                              await _reload();
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

enum _AddMode { enroll, claim, importBackup }

/// Add site: probe → enroll / claim / import backup → manage.
class OpsAddSitePage extends StatefulWidget {
  const OpsAddSitePage({super.key});

  @override
  State<OpsAddSitePage> createState() => _OpsAddSitePageState();
}

class _OpsAddSitePageState extends State<OpsAddSitePage> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _claimCtrl = TextEditingController();
  final _importPassCtrl = TextEditingController();
  final _importBlobCtrl = TextEditingController();
  String _status = '';
  OpsProbeOutcome? _outcome;
  String? _resolvedBaseUrl;
  bool _busy = false;
  _AddMode _mode = _AddMode.enroll;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _secretCtrl.dispose();
    _claimCtrl.dispose();
    _importPassCtrl.dispose();
    _importBlobCtrl.dispose();
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
    final titleCheck = OpsValidators.siteTitle(_titleCtrl.text);
    if (!titleCheck.ok) {
      setState(() {
        _status = titleCheck.error!;
        _outcome = null;
        _resolvedBaseUrl = null;
      });
      return;
    }
    final endpointCheck = OpsValidators.siteEndpoint(_urlCtrl.text);
    if (!endpointCheck.ok) {
      setState(() {
        _status = endpointCheck.error!;
        _outcome = null;
        _resolvedBaseUrl = null;
      });
      return;
    }
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
        if (resolved.outcome.kind == OpsProbeKind.needReset) {
          // 他机备份优先于重置；认领码仍可选手动切换。
          _mode = _AddMode.importBackup;
        } else if (resolved.outcome.kind == OpsProbeKind.pending) {
          _mode = _AddMode.enroll;
        }
        final tried = resolved.tried.join(' → ');
        final next = resolved.outcome.nextStep;
        _status = [
          resolved.outcome.message,
          if (next != null && next.isNotEmpty) next,
          if (resolved.tried.length > 1) '尝试：$tried',
        ].join('\n');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistAndOpen({
    required OpsSiteStore store,
    required OpsSiteEntry site,
    required OpsEnrollResult enrolled,
  }) async {
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
  }

  Future<void> _enrollAndOpen() async {
    if (_busy) return;
    final base = _effectiveBaseUrl();
    final endpointCheck = OpsValidators.siteEndpoint(_urlCtrl.text);
    if (!endpointCheck.ok || base.isEmpty) {
      setState(() => _status = endpointCheck.error ?? '请先填写有效地址并探测');
      return;
    }
    final secretCheck = OpsValidators.enrollSecret(_secretCtrl.text);
    if (!secretCheck.ok) {
      setState(() => _status = secretCheck.error!);
      return;
    }
    final secret = _secretCtrl.text.trim();
    if (_outcome?.kind != OpsProbeKind.pending) {
      setState(() => _status = '请先探测，且站点需处于可首次入驻状态');
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
      await _persistAndOpen(store: store, site: site, enrolled: enrolled);
    } catch (e) {
      setState(() => _status = '入驻失败：${OpsErrorMessage.display(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claimAndOpen() async {
    if (_busy) return;
    final base = _effectiveBaseUrl();
    final endpointCheck = OpsValidators.siteEndpoint(_urlCtrl.text);
    if (!endpointCheck.ok || base.isEmpty) {
      setState(() => _status = endpointCheck.error ?? '请先填写有效地址并探测');
      return;
    }
    final secretCheck = OpsValidators.claimSecret(_claimCtrl.text);
    if (!secretCheck.ok) {
      setState(() => _status = secretCheck.error!);
      return;
    }
    final secret = _claimCtrl.text.trim();
    setState(() {
      _busy = true;
      _status = '认领入驻中…';
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
      final enrolled = await client.claim(claimSecret: secret, label: 'autumn-ops');
      await _persistAndOpen(store: store, site: site, enrolled: enrolled);
    } catch (e) {
      setState(() => _status = '认领失败：${OpsErrorMessage.display(e)}');
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

  /// 他机导出的口令包 → 本机落库同一 certId（换机/重装，不是给同事单独发证）。
  Future<void> _importBackupAndOpen() async {
    if (_busy) return;
    final base = _effectiveBaseUrl();
    final endpointCheck = OpsValidators.siteEndpoint(_urlCtrl.text);
    if (!endpointCheck.ok || base.isEmpty) {
      setState(() => _status = endpointCheck.error ?? '请先填写有效地址并探测');
      return;
    }
    if (_outcome == null ||
        _outcome!.kind == OpsProbeKind.network ||
        _outcome!.kind == OpsProbeKind.incompatible ||
        _outcome!.kind == OpsProbeKind.forbidden) {
      setState(() => _status = '请先成功探测到 Autumn 运维接口');
      return;
    }
    final passCheck = OpsValidators.sharePassphrase(_importPassCtrl.text);
    if (!passCheck.ok) {
      setState(() => _status = passCheck.error!);
      return;
    }
    final blobCheck = OpsValidators.backupBlob(_importBlobCtrl.text);
    if (!blobCheck.ok) {
      setState(() => _status = blobCheck.error!);
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在导入并校验会话…';
    });
    OpsSiteStore? store;
    OpsSiteEntry? site;
    try {
      store = await openOpsSiteStore();
      site = OpsSiteEntry(
        id: const Uuid().v4(),
        title: _titleCtrl.text.trim().isEmpty ? base : _titleCtrl.text.trim(),
        baseUrl: base,
      );
      final cred = store.credentialStoreFor(site);
      final client = AutumnOpsClient(baseUrl: base, store: cred);
      await client.importWrapped(
        _importBlobCtrl.text.trim(),
        _importPassCtrl.text.trim(),
      );
      final bundle = await client.currentBundle();
      if (bundle == null) {
        await cred.clear();
        setState(() => _status = '导入失败：未读到本机证书包');
        return;
      }
      final probeFp = _outcome?.result?.serverFingerprint;
      if (probeFp != null &&
          probeFp.isNotEmpty &&
          (bundle.serverFingerprint ?? '').isNotEmpty &&
          probeFp != bundle.serverFingerprint) {
        await cred.clear();
        setState(() {
          _status =
              '导入的备份与当前探测站点指纹不一致，已取消。请确认地址是否为同一 Autumn 实例。';
        });
        return;
      }
      await client.ensureSession();
      site.siteId =
          bundle.siteId.isNotEmpty ? bundle.siteId : _outcome?.result?.siteId;
      site.certId = bundle.certId;
      site.serverFingerprint =
          bundle.serverFingerprint ?? _outcome?.result?.serverFingerprint;
      site.enrolled = true;
      await store.upsertSite(site);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OpsManageSitePage(siteId: site!.id),
        ),
      );
    } catch (e) {
      if (store != null && site != null) {
        try {
          await store.credentialStoreFor(site).clear();
        } catch (_) {}
      }
      setState(() {
        _status =
            '导入失败：${OpsErrorMessage.display(e)}\n'
            '请核对分享口令与密文；若该证书已在服务端吊销，请改用「认领码入驻」或重置后首次入驻。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEnroll = _outcome?.kind == OpsProbeKind.pending;
    final canClaim = _outcome?.kind == OpsProbeKind.needReset ||
        _outcome?.kind == OpsProbeKind.ready ||
        _outcome?.kind == OpsProbeKind.pending;
    final canImport = _outcome?.kind == OpsProbeKind.needReset ||
        _outcome?.kind == OpsProbeKind.ready ||
        _outcome?.kind == OpsProbeKind.pending;
    final canOpenReady = _outcome?.kind == OpsProbeKind.ready;
    final needReset = _outcome?.kind == OpsProbeKind.needReset;

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
              helperText: '域名优先 https 再 http；IP（含内网）用 http。已写协议则不再自动拼接。',
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) {
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
          FilledButton(
            onPressed: _busy ? null : _probe,
            child: const Text('探测'),
          ),
          if (_outcome != null) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_outcome!.message, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (_outcome!.nextStep != null) ...[
                      const SizedBox(height: 6),
                      Text(_outcome!.nextStep!, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (needReset) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OpsRecoveryPage(
                      siteTitle: _titleCtrl.text.trim(),
                      baseUrl: _effectiveBaseUrl(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.healing),
              label: const Text('查看运维墙 / 数据库恢复步骤'),
            ),
          ],
          if (canEnroll || canClaim || canImport) ...[
            const SizedBox(height: 16),
            SegmentedButton<_AddMode>(
              segments: const [
                ButtonSegment(
                  value: _AddMode.enroll,
                  label: Text('首次'),
                  icon: Icon(Icons.key),
                ),
                ButtonSegment(
                  value: _AddMode.claim,
                  label: Text('认领码'),
                  icon: Icon(Icons.qr_code),
                ),
                ButtonSegment(
                  value: _AddMode.importBackup,
                  label: Text('备份导入'),
                  icon: Icon(Icons.file_download_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            if (_mode == _AddMode.enroll) ...[
              TextField(
                controller: _secretCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '入驻口令',
                  helperText: '从服务器控制台日志复制「OpsEnroll secret=」后的口令',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || !canEnroll ? null : _enrollAndOpen,
                child: const Text('入驻并进入管理'),
              ),
              if (!canEnroll)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '当前不是「可首次入驻」。已有管理员设备请用「认领码」；换机请用「备份导入」。',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
            ] else if (_mode == _AddMode.claim) ...[
              const Text(
                '新设备各自生成密钥，可单独吊销。由已登录设备在「证书」页签发认领码。',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _claimCtrl,
                decoration: const InputDecoration(
                  labelText: '认领码',
                  helperText: '约 30 分钟有效，单次消费',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || !canClaim ? null : _claimAndOpen,
                child: const Text('认领并进入管理'),
              ),
            ] else ...[
              const Text(
                '换机或重装：粘贴他机「证书」页导出的口令包，与导出时相同的分享口令。'
                '导入后与源设备共享同一证书标识；给同事单独一台机请用「认领码」。',
                style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _importPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '分享口令',
                  helperText: '须与导出时填写的口令一致',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _importBlobCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '备份密文',
                  hintText: '粘贴 .ops 文件全文，或分享内容中的 Base64 密文',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy || !canImport ? null : _importBackupAndOpen,
                child: const Text('导入并进入管理'),
              ),
            ],
          ],
          if (canOpenReady) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _saveReadyAndOpen,
              child: const Text('本机已有证书 · 保存并进入管理'),
            ),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
