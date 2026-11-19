import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'ops_backup_io.dart';
import 'ops_fused_field.dart';
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
                      '点右上角「+」：① 首次口令 ② 认领码（文字）③ 换机选 .ops 备份文件。',
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
  const OpsAddSitePage({
    super.key,
    this.initialBaseUrl,
    this.autoProbe = false,
  });

  /// Prefill address (e.g. from discover Gate).
  final String? initialBaseUrl;

  /// When true and [initialBaseUrl] set, run probe after first frame.
  final bool autoProbe;

  @override
  State<OpsAddSitePage> createState() => _OpsAddSitePageState();
}

class _OpsAddSitePageState extends State<OpsAddSitePage> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _claimCtrl = TextEditingController();
  final _importPassCtrl = TextEditingController();
  String _status = '';
  OpsProbeOutcome? _outcome;
  String? _resolvedBaseUrl;
  bool _busy = false;
  _AddMode _mode = _AddMode.enroll;
  OpsBackupFile? _pickedBackup;
  String? _pickedBackupName;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialBaseUrl ?? '').trim();
    if (initial.isNotEmpty) {
      final n = OpsSiteEntry.normalizeBaseUrl(initial);
      _urlCtrl.text = n;
      _titleCtrl.text = n;
      if (widget.autoProbe) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _probe();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _secretCtrl.dispose();
    _claimCtrl.dispose();
    _importPassCtrl.dispose();
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

  Future<void> _pickBackupFile() async {
    final picked = await pickOpsBackupFile();
    if (!mounted) return;
    if (picked.cancelled) return;
    if (!picked.ok) {
      setState(() => _status = picked.error ?? '选择备份失败');
      return;
    }
    setState(() {
      _pickedBackup = picked.file;
      _pickedBackupName = picked.displayName;
      _status = '已选择备份：${picked.displayName}';
      final hintUrl = picked.file!.baseUrl;
      if ((hintUrl ?? '').isNotEmpty && _urlCtrl.text.trim().isEmpty) {
        _urlCtrl.text = hintUrl!;
      }
    });
  }

  /// 他机导出的 .ops → 本机落库同一 certId（换机/重装，不是给同事单独发证）。
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
    final backup = _pickedBackup;
    if (backup == null) {
      setState(() => _status = '请先点「选择 .ops 备份文件」');
      return;
    }
    final passCheck = OpsValidators.sharePassphrase(_importPassCtrl.text);
    if (!passCheck.ok) {
      setState(() => _status = passCheck.error!);
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
      await client.importWrapped(backup.wrapped, _importPassCtrl.text.trim());
      final bundle = await client.currentBundle();
      if (bundle == null) {
        await cred.clear();
        setState(() => _status = '导入失败：未读到本机证书包');
        return;
      }
      final probeFp = _outcome?.result?.serverFingerprint;
      final fileFp = backup.serverFingerprint ?? bundle.serverFingerprint;
      if (probeFp != null &&
          probeFp.isNotEmpty &&
          (fileFp ?? '').isNotEmpty &&
          probeFp != fileFp) {
        await cred.clear();
        setState(() {
          _status =
              '备份与当前探测站点指纹不一致，已取消。请确认地址是否为同一 Autumn 实例。';
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
            '请核对：① 是否选对了 .ops 文件；② 分享口令是否与导出时一致；'
            '③ 证书是否已在服务端吊销（若是请改用「认领码」）。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteClipboard(TextEditingController ctrl) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim() ?? '';
    if (t.isEmpty) {
      setState(() => _status = '剪贴板没有可用文本');
      return;
    }
    setState(() {
      ctrl.text = t;
      _status = '已从剪贴板粘贴';
    });
  }

  Color _outcomeAccent(ColorScheme scheme, OpsProbeKind kind) {
    switch (kind) {
      case OpsProbeKind.pending:
      case OpsProbeKind.ready:
        return scheme.tertiary;
      case OpsProbeKind.needReset:
        return scheme.secondary;
      case OpsProbeKind.forbidden:
      case OpsProbeKind.incompatible:
      case OpsProbeKind.network:
        return scheme.error;
    }
  }

  Widget _buildProbeResultCard(ColorScheme scheme) {
    final o = _outcome!;
    final accent = _outcomeAccent(scheme, o.kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.message,
                  style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                if (o.nextStep != null && o.nextStep!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    o.nextStep!,
                    style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
                  ),
                ],
                if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '可用地址：$_resolvedBaseUrl',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasteIcon(TextEditingController ctrl) {
    return IconButton(
      tooltip: '从剪贴板粘贴',
      onPressed: _busy ? null : () => _pasteClipboard(ctrl),
      icon: const Icon(Icons.content_paste, size: 20),
    );
  }

  Widget _buildJoinBody({
    required bool canEnroll,
    required bool canClaim,
    required bool canImport,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final hintStyle = TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant);

    switch (_mode) {
      case _AddMode.enroll:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('从服务器控制台日志复制「OpsEnroll secret=」后的口令。', style: hintStyle),
            const SizedBox(height: 10),
            OpsFusedFieldAction(
              controller: _secretCtrl,
              hintText: '入驻口令',
              actionLabel: '入驻',
              obscure: true,
              enabled: !_busy,
              trailing: _pasteIcon(_secretCtrl),
              onAction: _busy || !canEnroll ? null : _enrollAndOpen,
            ),
            if (!canEnroll) ...[
              const SizedBox(height: 8),
              Text(
                '当前不可首次入驻。已有管理员设备 →「认领码」；换机带了 .ops →「换机备份」。',
                style: hintStyle,
              ),
            ],
          ],
        );
      case _AddMode.claim:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '粘贴已登录设备「证书」页签发的认领码（文字，约 30 分钟）。不是 .ops 文件。',
              style: hintStyle,
            ),
            const SizedBox(height: 10),
            OpsFusedFieldAction(
              controller: _claimCtrl,
              hintText: '认领码',
              actionLabel: '认领',
              enabled: !_busy,
              trailing: _pasteIcon(_claimCtrl),
              onAction: _busy || !canClaim ? null : _claimAndOpen,
            ),
          ],
        );
      case _AddMode.importBackup:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择他机导出的 .ops 文件，再填导出时的分享口令。给同事新设备请用「认领码」。',
              style: hintStyle,
            ),
            const SizedBox(height: 10),
            OpsFusedActionBar(
              icon: Icons.folder_open,
              label: _pickedBackupName == null
                  ? '尚未选择备份文件'
                  : '已选：$_pickedBackupName',
              actionLabel: _pickedBackupName == null ? '选文件' : '重选',
              enabled: !_busy,
              onAction: _pickBackupFile,
            ),
            if (_pickedBackup?.baseUrl != null && _pickedBackup!.baseUrl!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '文件内站点：${_pickedBackup!.baseUrl}',
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),
            OpsFusedFieldAction(
              controller: _importPassCtrl,
              hintText: '分享口令（与导出时相同）',
              actionLabel: '导入',
              obscure: true,
              enabled: !_busy,
              onAction: _busy || !canImport ? null : _importBackupAndOpen,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canEnroll = _outcome?.kind == OpsProbeKind.pending;
    final canClaim = _outcome?.kind == OpsProbeKind.needReset ||
        _outcome?.kind == OpsProbeKind.ready ||
        _outcome?.kind == OpsProbeKind.pending;
    final canImport = _outcome?.kind == OpsProbeKind.needReset ||
        _outcome?.kind == OpsProbeKind.ready ||
        _outcome?.kind == OpsProbeKind.pending;
    final canOpenReady = _outcome?.kind == OpsProbeKind.ready;
    final needReset = _outcome?.kind == OpsProbeKind.needReset;
    final showJoin = canEnroll || canClaim || canImport;

    return Scaffold(
      appBar: AppBar(title: const Text('添加站点')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          OpsAddSection(
            title: '1. 站点地址',
            subtitle: '域名优先 https 再 http；IP（含内网）用 http。已写协议则不再自动拼接。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TextField(
                    controller: _titleCtrl,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 15, height: 1.2),
                    decoration: InputDecoration(
                      hintText: '显示名称（选填，如：生产机房）',
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OpsFusedFieldAction(
                  controller: _urlCtrl,
                  hintText: '域名或 IP，如 example.com / 192.168.1.10',
                  actionLabel: _busy && _outcome == null ? '探测中' : '探测',
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (_resolvedBaseUrl != null || _outcome != null) {
                      setState(() {
                        _resolvedBaseUrl = null;
                        _outcome = null;
                      });
                    }
                  },
                  onAction: _busy ? null : _probe,
                ),
              ],
            ),
          ),
          if (_outcome != null) ...[
            const SizedBox(height: 12),
            OpsAddSection(
              title: '2. 探测结果',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProbeResultCard(scheme),
                  if (needReset) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
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
                        icon: const Icon(Icons.healing, size: 18),
                        label: const Text('无备份时的恢复步骤'),
                      ),
                    ),
                  ],
                  if (canOpenReady) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: _busy ? null : _saveReadyAndOpen,
                        child: const Text('本机已有证书 · 直接进入管理'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (showJoin) ...[
            const SizedBox(height: 12),
            OpsAddSection(
              title: _outcome == null ? '2. 接入方式' : '3. 接入方式',
              subtitle: '按你的情况选一种：首次 / 认领新设备 / 换机恢复。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_AddMode>(
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: _AddMode.enroll,
                        label: Text('首次'),
                        icon: Icon(Icons.key, size: 16),
                      ),
                      ButtonSegment(
                        value: _AddMode.claim,
                        label: Text('认领码'),
                        icon: Icon(Icons.qr_code, size: 16),
                      ),
                      ButtonSegment(
                        value: _AddMode.importBackup,
                        label: Text('换机'),
                        icon: Icon(Icons.folder_open, size: 16),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  _buildJoinBody(
                    canEnroll: canEnroll,
                    canClaim: canClaim,
                    canImport: canImport,
                  ),
                ],
              ),
            ),
          ],
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _status,
              style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
