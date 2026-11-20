import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';

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

  /// 发现 URL / 深链。无法识别时返回 false。
  static Future<bool> openDiscover(BuildContext context, String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return false;
    final base = AutumnOpsDiscover.tryParseBaseUrl(trimmed) ??
        AutumnOpsDiscover.tryParseBaseUrl(trimmed, forceHttpBase: true);
    if (base == null || base.isEmpty) return false;

    final store = await openOpsSiteStore();
    final existing = await store.findByBaseUrl(base);
    if (existing != null &&
        existing.enrolled &&
        await store.hasLocalCredential(existing) &&
        context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OpsManageSitePage(siteId: existing.id),
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
