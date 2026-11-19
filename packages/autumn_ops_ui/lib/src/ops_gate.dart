import 'dart:io';
import 'dart:typed_data';

import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ops_fused_field.dart';
import 'ops_manage_page.dart';
import 'ops_pages.dart';
import 'ops_site_io.dart';

/// Host-facing root: open `.ops` bytes/path or a discover URL.
///
/// Product apps push this page; all import / probe UI stays in packages.
class AutumnOpsGatePage extends StatefulWidget {
  const AutumnOpsGatePage._({
    super.key,
    this.bytes,
    this.path,
    this.filename,
    this.rawUrl,
  });

  factory AutumnOpsGatePage.opsBytes({
    Key? key,
    required Uint8List bytes,
    String? filename,
  }) {
    return AutumnOpsGatePage._(key: key, bytes: bytes, filename: filename);
  }

  factory AutumnOpsGatePage.opsPath({
    Key? key,
    required String path,
    String? filename,
  }) {
    return AutumnOpsGatePage._(key: key, path: path, filename: filename);
  }

  factory AutumnOpsGatePage.discover({
    Key? key,
    required String rawUrl,
  }) {
    return AutumnOpsGatePage._(key: key, rawUrl: rawUrl);
  }

  final Uint8List? bytes;
  final String? path;
  final String? filename;
  final String? rawUrl;

  @override
  State<AutumnOpsGatePage> createState() => _AutumnOpsGatePageState();
}

class _AutumnOpsGatePageState extends State<AutumnOpsGatePage> {
  String _status = '准备中…';
  bool _busy = false;
  OpsBackupFile? _backup;
  final _passCtrl = TextEditingController();
  String? _discoverBase;
  OpsProbeOutcome? _probeOutcome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (widget.rawUrl != null) {
      await _startDiscover(widget.rawUrl!);
      return;
    }
    await _startOpsFile();
  }

  Future<void> _startOpsFile() async {
    setState(() {
      _busy = true;
      _status = '正在读取备份…';
    });
    try {
      final String raw;
      if (widget.bytes != null) {
        raw = String.fromCharCodes(widget.bytes!);
      } else if (widget.path != null) {
        raw = await File(widget.path!).readAsString();
      } else {
        setState(() => _status = '未提供备份数据');
        return;
      }
      final parsed = OpsBackupFile.parse(raw);
      if (!parsed.ok || parsed.file == null) {
        setState(() => _status = parsed.error ?? '无法解析 .ops 文件');
        return;
      }
      _backup = parsed.file;
      final store = await openOpsSiteStore();
      final certId = (_backup!.certId ?? '').trim();
      if (certId.isNotEmpty) {
        final hit = await store.findByCertId(certId);
        if (hit != null && await store.hasLocalCredential(hit)) {
          if (!mounted) return;
          _goManage(hit.id, replace: true);
          return;
        }
      }
      final baseHint = (_backup!.baseUrl ?? '').trim();
      if (baseHint.isNotEmpty) {
        final byBase = await store.findByBaseUrl(baseHint);
        if (byBase != null &&
            (byBase.certId ?? '').isNotEmpty &&
            certId.isNotEmpty &&
            byBase.certId == certId &&
            await store.hasLocalCredential(byBase)) {
          if (!mounted) return;
          _goManage(byBase.id, replace: true);
          return;
        }
      }
      setState(() {
        _status = '需要分享口令以导入运维证书';
      });
    } catch (e) {
      setState(() => _status = '读取失败：${OpsErrorMessage.display(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importWithPassphrase() async {
    final backup = _backup;
    if (backup == null || _busy) return;
    final passCheck = OpsValidators.sharePassphrase(_passCtrl.text);
    if (!passCheck.ok) {
      setState(() => _status = passCheck.error!);
      return;
    }
    var base = (backup.baseUrl ?? '').trim();
    if (base.isEmpty) {
      setState(() => _status = '备份未含站点地址，请改用「添加站点」换机流程');
      return;
    }
    base = OpsSiteEntry.normalizeBaseUrl(base);
    setState(() {
      _busy = true;
      _status = '正在导入并校验…';
    });
    OpsSiteStore? store;
    OpsSiteEntry? site;
    try {
      store = await openOpsSiteStore();
      // Decrypt first to resolve certId for merge.
      final tmpId = const Uuid().v4();
      site = OpsSiteEntry(
        id: tmpId,
        title: base,
        baseUrl: base,
      );
      final existingByBase = await store.findByBaseUrl(base);
      if (existingByBase != null) {
        site = existingByBase;
      }
      final cred = store.credentialStoreFor(site);
      final client = AutumnOpsClient(baseUrl: base, store: cred);
      await client.importWrapped(backup.wrapped, _passCtrl.text.trim());
      final bundle = await client.currentBundle();
      if (bundle == null) {
        await cred.clear();
        setState(() => _status = '导入失败：未读到本机证书包');
        return;
      }
      final byCert = await store.findByCertId(bundle.certId);
      if (byCert != null && byCert.id != site.id) {
        // Merge onto existing cert row; clear temp if we created one.
        if (site.id == tmpId) {
          await cred.clear();
        }
        site = byCert;
        final mergeCred = store.credentialStoreFor(site);
        final mergeClient =
            AutumnOpsClient(baseUrl: site.baseUrl, store: mergeCred);
        await mergeClient.importWrapped(backup.wrapped, _passCtrl.text.trim());
        await mergeClient.ensureSession();
        site.siteId =
            bundle.siteId.isNotEmpty ? bundle.siteId : site.siteId;
        site.certId = bundle.certId;
        site.serverFingerprint =
            bundle.serverFingerprint ?? backup.serverFingerprint;
        site.enrolled = true;
        await store.upsertSite(site);
        if (!mounted) return;
        _goManage(site.id, replace: true);
        return;
      }
      final fileFp = backup.serverFingerprint ?? bundle.serverFingerprint;
      // Soft probe for fingerprint when possible.
      try {
        final plan = OpsEndpoint.resolve(base);
        if (!plan.isEmpty) {
          final resolved = await OpsEndpoint.probePlan(
            plan: plan,
            store: cred,
            hasLocalCert: true,
          );
          final probeFp = resolved.outcome.result?.serverFingerprint;
          if (probeFp != null &&
              probeFp.isNotEmpty &&
              (fileFp ?? '').isNotEmpty &&
              probeFp != fileFp) {
            await cred.clear();
            setState(() {
              _status =
                  '备份与站点指纹不一致，已取消。请确认是否为同一 Autumn 实例。';
            });
            return;
          }
        }
      } catch (_) {}
      await client.ensureSession();
      site.siteId = bundle.siteId.isNotEmpty ? bundle.siteId : site.siteId;
      site.certId = bundle.certId;
      site.serverFingerprint = fileFp;
      site.enrolled = true;
      if (site.title.trim().isEmpty) {
        site.title = base;
      }
      await store.upsertSite(site);
      if (!mounted) return;
      _goManage(site.id, replace: true);
    } catch (e) {
      if (store != null && site != null) {
        try {
          await store.credentialStoreFor(site).clear();
        } catch (_) {}
      }
      setState(() {
        _status =
            '导入失败：${OpsErrorMessage.display(e)}\n请核对分享口令与证书是否仍有效。';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startDiscover(String rawUrl) async {
    final base = AutumnOpsDiscover.tryParseBaseUrl(rawUrl) ??
        AutumnOpsDiscover.tryParseBaseUrl(rawUrl, forceHttpBase: true);
    if (base == null || base.isEmpty) {
      setState(() => _status = '无法识别运维发现地址');
      return;
    }
    _discoverBase = base;
    setState(() {
      _busy = true;
      _status = '正在探测 $base …';
      _probeOutcome = null;
    });
    try {
      final store = await openOpsSiteStore();
      final existing = await store.findByBaseUrl(base);
      if (existing != null &&
          existing.enrolled &&
          await store.hasLocalCredential(existing)) {
        if (!mounted) return;
        _goManage(existing.id, replace: true);
        return;
      }
      final probeStore = store.credentialStoreFor(
        existing ??
            OpsSiteEntry(id: 'tmp', title: '', baseUrl: base),
      );
      final hasCert = await probeStore.load() != null;
      final plan = OpsEndpoint.resolve(base);
      final resolved = await OpsEndpoint.probePlan(
        plan: plan,
        store: probeStore,
        hasLocalCert: hasCert,
      );
      if (!mounted) return;
      final effectiveBase =
          resolved.baseUrl.isNotEmpty ? resolved.baseUrl : base;
      _discoverBase = effectiveBase;
      if (resolved.outcome.kind == OpsProbeKind.ready && hasCert) {
        final site = existing ??
            await store.findByBaseUrl(effectiveBase) ??
            OpsSiteEntry(
              id: const Uuid().v4(),
              title: effectiveBase,
              baseUrl: effectiveBase,
              enrolled: true,
            );
        if (existing == null) {
          final b = await probeStore.load();
          site.certId = b?.certId;
          site.siteId = b?.siteId ?? resolved.outcome.result?.siteId;
          site.serverFingerprint = b?.serverFingerprint ??
              resolved.outcome.result?.serverFingerprint;
          site.enrolled = true;
          await store.upsertSite(site);
        }
        _goManage(site.id, replace: true);
        return;
      }
      setState(() {
        _probeOutcome = resolved.outcome;
        final next = resolved.outcome.nextStep;
        _status = [
          resolved.outcome.message,
          if (next != null && next.isNotEmpty) next,
        ].join('\n');
      });
    } catch (e) {
      setState(() => _status = '探测失败：${OpsErrorMessage.display(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goManage(String siteId, {required bool replace}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => OpsManageSitePage(siteId: siteId),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _openAddSite() {
    final base = _discoverBase;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OpsAddSitePage(
          initialBaseUrl: base,
          autoProbe: base != null && base.isNotEmpty,
        ),
      ),
    );
  }

  void _openSites() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const OpsSitesPage()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOps = widget.rawUrl == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isOps ? '打开运维备份' : 'Autumn 运维发现'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _openSites,
            child: const Text('站点列表'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (isOps && _backup != null && !_busy) ...[
            const SizedBox(height: 16),
            if ((_backup!.baseUrl ?? '').isNotEmpty)
              Text('站点：${_backup!.baseUrl}',
                  style: Theme.of(context).textTheme.bodyMedium),
            if ((_backup!.certId ?? '').isNotEmpty)
              Text('证书：${_backup!.certId}',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            OpsFusedFieldAction(
              controller: _passCtrl,
              hintText: '分享口令',
              actionLabel: '导入并进入',
              obscure: true,
              enabled: !_busy,
              onAction: _importWithPassphrase,
            ),
          ],
          if (!isOps && !_busy && _probeOutcome != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _openAddSite,
              child: const Text('继续添加 / 入驻'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _openSites,
              child: const Text('打开站点列表'),
            ),
          ],
        ],
      ),
    );
  }
}
