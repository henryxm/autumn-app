import 'dart:convert';

import 'ops_store.dart';
import 'ops_validators.dart';

/// 运维证书备份文件（`.ops`）读写。
///
/// 导出为 JSON：元数据明文可见（便于核对站点），私钥包仍在 [wrapped] 中用分享口令加密。
/// 兼容旧版：纯 Base64 密文（无 JSON 外壳）。
class OpsBackupFile {
  const OpsBackupFile({
    required this.wrapped,
    this.baseUrl,
    this.siteId,
    this.certId,
    this.serverFingerprint,
    this.createdAtMs,
  });

  static const kind = 'autumn-ops-backup';
  static const currentVersion = 1;
  static const fileExtension = 'ops';

  /// 口令包裹后的证书密文（Base64）。
  final String wrapped;
  final String? baseUrl;
  final String? siteId;
  final String? certId;
  final String? serverFingerprint;
  final int? createdAtMs;

  /// 从 [OpsStore.exportPassphraseWrapped] 结果与站点元数据组装导出内容。
  static String encode({
    required String wrappedCipher,
    String? baseUrl,
    String? siteId,
    String? certId,
    String? serverFingerprint,
  }) {
    final map = <String, dynamic>{
      'v': currentVersion,
      'kind': kind,
      'wrapped': wrappedCipher.trim(),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      if (baseUrl != null && baseUrl.isNotEmpty) 'baseUrl': baseUrl,
      if (siteId != null && siteId.isNotEmpty) 'siteId': siteId,
      if (certId != null && certId.isNotEmpty) 'certId': certId,
      if (serverFingerprint != null && serverFingerprint.isNotEmpty)
        'serverFingerprint': serverFingerprint,
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// 解析文件正文：结构化 JSON 或旧版纯密文。
  static OpsBackupParseResult parse(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsBackupParseResult.fail('备份文件为空');
    }
    if (s.startsWith('{')) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final k = '${map['kind'] ?? ''}';
        if (k.isNotEmpty && k != kind) {
          return OpsBackupParseResult.fail('不是 Autumn 运维备份（kind=$k）');
        }
        final wrapped = '${map['wrapped'] ?? ''}'.trim();
        final blob = OpsValidators.backupBlob(wrapped);
        if (!blob.ok) {
          return OpsBackupParseResult.fail(blob.error ?? '备份密文无效');
        }
        return OpsBackupParseResult.ok(
          OpsBackupFile(
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
      } catch (e) {
        return OpsBackupParseResult.fail('备份文件 JSON 无法解析');
      }
    }
    final blob = OpsValidators.backupBlob(s);
    if (!blob.ok) {
      return OpsBackupParseResult.fail(
        blob.error ?? '无法识别备份：请选择 .ops 文件或确认内容完整',
      );
    }
    return OpsBackupParseResult.ok(OpsBackupFile(wrapped: s));
  }
}

class OpsBackupParseResult {
  const OpsBackupParseResult._({this.file, this.error});

  const OpsBackupParseResult.ok(OpsBackupFile file) : this._(file: file);

  const OpsBackupParseResult.fail(String error) : this._(error: error);

  final OpsBackupFile? file;
  final String? error;

  bool get ok => file != null && error == null;
}
