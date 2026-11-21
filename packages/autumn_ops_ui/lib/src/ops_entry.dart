import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ops_gate.dart';
import 'ops_manage_page.dart';
import 'ops_site_io.dart';

/// 统一打开入口：本机已有匹配凭证 → 直推 Manage；否则 Gate（导入/发现）。
///
/// 宿主（超然信 / 独立 shell）只调本类，禁止无条件 push Gate。
abstract final class AutumnOpsEntry {
  AutumnOpsEntry._();

  /// IM 气泡 / 收藏 content（`kind=autumn-ops` map）。
  static Future<void> openPayload(
    BuildContext context,
    Map<String, dynamic> content,
  ) async {
    if (!context.mounted) return;
    final parsed = AutumnOpsPayload.fromMessageMap(content);
    if (parsed.ok && parsed.payload != null) {
      final siteId = await _resolveManageSiteId(parsed.payload!);
      if (siteId != null && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => OpsManageSitePage(siteId: siteId),
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AutumnOpsGatePage.fromContent(content: content),
      ),
    );
  }

  /// 发现 URL / 深链。
  ///
  /// 仅 `{base}/autumn/ops/discover` 或 `…/autumnops?base=` 才探测；
  /// 探测失败返回 `false`（宿主走原 URL 打开流）；
  /// 探测成功且本机有证 → Manage；成功无证 → Gate。
  static Future<bool> openDiscover(BuildContext context, String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final base = AutumnOpsDiscover.tryParseBaseUrl(trimmed);
    if (base == null || base.isEmpty) return false;

    final store = await openOpsSiteStore();
    final existing = await store.findByBaseUrl(base);
    final probeSite = existing ??
        OpsSiteEntry(id: 'tmp', title: '', baseUrl: base);
    final probeStore = store.credentialStoreFor(probeSite);
    final hasCert = await probeStore.load() != null;

    final plan = OpsEndpoint.resolve(base);
    final resolved = await OpsEndpoint.probePlan(
      plan: plan,
      store: probeStore,
      hasLocalCert: hasCert,
    );
    if (!_isAutumnOpsConfirmed(resolved.outcome.kind)) {
      return false;
    }

    final effectiveBase =
        resolved.baseUrl.isNotEmpty ? resolved.baseUrl : base;

    if (hasCert && context.mounted) {
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
        site.serverFingerprint =
            b?.serverFingerprint ?? resolved.outcome.result?.serverFingerprint;
        site.enrolled = true;
        await store.upsertSite(site);
      }
      if (!context.mounted) return false;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OpsManageSitePage(siteId: site.id),
        ),
      );
      return true;
    }

    if (!context.mounted) return false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AutumnOpsGatePage.discover(rawUrl: trimmed),
      ),
    );
    return true;
  }

  /// 确认服务端为 Autumn 运维能力（非网络/非兼容/非拒绝）。
  static bool _isAutumnOpsConfirmed(OpsProbeKind kind) {
    switch (kind) {
      case OpsProbeKind.pending:
      case OpsProbeKind.ready:
      case OpsProbeKind.needReset:
        return true;
      case OpsProbeKind.network:
      case OpsProbeKind.incompatible:
      case OpsProbeKind.forbidden:
        return false;
    }
  }

  /// 与 Gate `_startPayload` 同构：certId 或 base+certId 命中且有本地证。
  static Future<String?> _resolveManageSiteId(AutumnOpsPayload payload) async {
    final store = await openOpsSiteStore();
    final certId = (payload.certId ?? '').trim();
    if (certId.isNotEmpty) {
      final hit = await store.findByCertId(certId);
      if (hit != null && await store.hasLocalCredential(hit)) {
        return hit.id;
      }
    }
    final baseHint = (payload.baseUrl ?? '').trim();
    if (baseHint.isNotEmpty && certId.isNotEmpty) {
      final byBase = await store.findByBaseUrl(baseHint);
      if (byBase != null &&
          (byBase.certId ?? '').isNotEmpty &&
          byBase.certId == certId &&
          await store.hasLocalCredential(byBase)) {
        return byBase.id;
      }
    }
    return null;
  }
}
