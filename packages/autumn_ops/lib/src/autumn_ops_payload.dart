import 'dart:convert';

import 'ops_validators.dart';

/// Autumn 运维密钥共享载荷（与 IM `AutumnOps` content 同构）。
///
/// 元数据明文；私钥包在 [wrapped] 中用分享口令包裹。口令永不写入载荷。
class AutumnOpsPayload {
  const AutumnOpsPayload({
    required this.wrapped,
    this.baseUrl,
    this.siteId,
    this.certId,
    this.serverFingerprint,
    this.createdAtMs,
  });

  static const kind = 'autumn-ops';
  static const currentVersion = 1;

  /// 本机凭证文件扩展名（非 IM；IM 仅认 `Data.type=AutumnOps`）。
  static const fileExtension = 'autumnops';

  /// Wire `Data.type`（im-api）。
  static const messageType = 'AutumnOps';

  final String wrapped;
  final String? baseUrl;
  final String? siteId;
  final String? certId;
  final String? serverFingerprint;
  final int? createdAtMs;

  static Map<String, dynamic> toMessageMap({
    required String wrappedCipher,
    String? baseUrl,
    String? siteId,
    String? certId,
    String? serverFingerprint,
    int? createdAtMs,
  }) {
    return <String, dynamic>{
      'v': currentVersion,
      'kind': kind,
      'wrapped': wrappedCipher.trim(),
      'createdAt': createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      if (baseUrl != null && baseUrl.isNotEmpty) 'baseUrl': baseUrl,
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      if (certId != null && certId.isNotEmpty) 'certId': certId,
      if (serverFingerprint != null && serverFingerprint.isNotEmpty)
        'serverFingerprint': serverFingerprint,
    };
  }

  Map<String, dynamic> toMap() => toMessageMap(
        wrappedCipher: wrapped,
        baseUrl: baseUrl,
        siteId: siteId,
        certId: certId,
        serverFingerprint: serverFingerprint,
        createdAtMs: createdAtMs,
      );

  static String encodeJson({
    required String wrappedCipher,
    String? baseUrl,
    String? siteId,
    String? certId,
    String? serverFingerprint,
  }) {
    return const JsonEncoder.withIndent('  ').convert(
      toMessageMap(
        wrappedCipher: wrappedCipher,
        baseUrl: baseUrl,
        siteId: siteId,
        certId: certId,
        serverFingerprint: serverFingerprint,
      ),
    );
  }

  static AutumnOpsParseResult fromMessageMap(Map<String, dynamic> map) {
    final k = '${map['kind'] ?? ''}'.trim();
    if (k != kind) {
      return AutumnOpsParseResult.fail(
        k.isEmpty ? '缺少 kind=autumn-ops' : '不是 Autumn 运维载荷（kind=$k）',
      );
    }
    final wrapped = '${map['wrapped'] ?? ''}'.trim();
    final blob = OpsValidators.wrappedBlob(wrapped);
    if (!blob.ok) {
      return AutumnOpsParseResult.fail(blob.error ?? '运维密文无效');
    }
    return AutumnOpsParseResult.ok(
      AutumnOpsPayload(
        wrapped: wrapped,
        baseUrl: map['baseUrl']?.toString(),
        siteId: map['siteId']?.toString(),
        certId: map['certId']?.toString(),
        serverFingerprint: map['serverFingerprint']?.toString(),
        createdAtMs: map['createdAt'] is int
            ? map['createdAt'] as int
            : int.tryParse('${map['createdAt'] ?? ''}'),
      ),
    );
  }

  /// 仅接受结构化 JSON（`kind=autumn-ops`）。
  static AutumnOpsParseResult parse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const AutumnOpsParseResult.fail('运维载荷为空');
    }
    if (!s.startsWith('{')) {
      return const AutumnOpsParseResult.fail('运维载荷须为 JSON');
    }
    try {
      final decoded = jsonDecode(s);
      if (decoded is! Map) {
        return const AutumnOpsParseResult.fail('运维载荷 JSON 须为对象');
      }
      return fromMessageMap(
        decoded.map((k, v) => MapEntry('$k', v)),
      );
    } catch (_) {
      return const AutumnOpsParseResult.fail('运维载荷 JSON 无法解析');
    }
  }
}

class AutumnOpsParseResult {
  const AutumnOpsParseResult._({this.payload, this.error});

  const AutumnOpsParseResult.ok(AutumnOpsPayload payload)
      : this._(payload: payload);

  const AutumnOpsParseResult.fail(String error) : this._(error: error);

  final AutumnOpsPayload? payload;
  final String? error;

  bool get ok => payload != null && error == null;
}
