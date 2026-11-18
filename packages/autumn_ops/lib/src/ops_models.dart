class OpsProbeResult {
  const OpsProbeResult({
    required this.autumn,
    required this.opsCert,
    required this.adminIpEnable,
    required this.enrollAvailable,
    this.siteId,
    this.serverFingerprint,
    this.protocolVersion,
  });

  final bool autumn;
  /// none | pending | ready
  final String opsCert;
  final bool adminIpEnable;
  final bool enrollAvailable;
  final String? siteId;
  final String? serverFingerprint;
  final int? protocolVersion;

  factory OpsProbeResult.fromJson(Map<String, dynamic> json) {
    return OpsProbeResult(
      autumn: json['autumn'] == true,
      opsCert: '${json['opsCert'] ?? 'none'}',
      adminIpEnable: json['adminIpEnable'] == true,
      enrollAvailable: json['enrollAvailable'] == true,
      siteId: json['siteId']?.toString(),
      serverFingerprint: json['serverFingerprint']?.toString(),
      protocolVersion: json['protocolVersion'] is int
          ? json['protocolVersion'] as int
          : int.tryParse('${json['protocolVersion'] ?? ''}'),
    );
  }
}

class OpsEnrollResult {
  const OpsEnrollResult({
    required this.certId,
    required this.siteId,
    required this.serverPublicKey,
    this.serverFingerprint,
  });

  final String certId;
  final String siteId;
  final String serverPublicKey;
  final String? serverFingerprint;

  factory OpsEnrollResult.fromJson(Map<String, dynamic> json) {
    return OpsEnrollResult(
      certId: '${json['certId'] ?? ''}',
      siteId: '${json['siteId'] ?? ''}',
      serverPublicKey: '${json['serverPublicKey'] ?? ''}',
      serverFingerprint: json['serverFingerprint']?.toString(),
    );
  }
}

/// 已登录设备签发的一次性认领码（明文仅本次响应）。
class OpsClaimIssueResult {
  const OpsClaimIssueResult({
    required this.claimId,
    required this.claimSecret,
    required this.expiresAt,
    this.siteId,
    this.serverFingerprint,
    this.label,
  });

  final String claimId;
  final String claimSecret;
  final int expiresAt;
  final String? siteId;
  final String? serverFingerprint;
  final String? label;

  factory OpsClaimIssueResult.fromJson(Map<String, dynamic> json) {
    return OpsClaimIssueResult(
      claimId: '${json['claimId'] ?? ''}',
      claimSecret: '${json['claimSecret'] ?? ''}',
      expiresAt: json['expiresAt'] is int
          ? json['expiresAt'] as int
          : int.tryParse('${json['expiresAt'] ?? ''}') ?? 0,
      siteId: json['siteId']?.toString(),
      serverFingerprint: json['serverFingerprint']?.toString(),
      label: json['label']?.toString(),
    );
  }
}

class OpsRevokeResult {
  const OpsRevokeResult({
    required this.success,
    required this.lastCert,
  });

  final bool success;
  final bool lastCert;

  factory OpsRevokeResult.fromJson(Map<String, dynamic> json) {
    return OpsRevokeResult(
      success: json['success'] == true,
      lastCert: json['lastCert'] == true,
    );
  }
}

/// 三类 IP 列表单行（管理 IP / 白名单 / 黑名单）。
class OpsIpRow {
  const OpsIpRow({
    required this.ip,
    this.tag,
    this.description,
    this.forbidden,
    this.available,
    this.createTimeMs,
  });

  final String ip;
  final String? tag;
  final String? description;

  /// 白名单类：`0` 启用 / `1` 禁用。
  final int? forbidden;

  /// 黑名单类：与 wall 一致——`0` 生效拦截 / `1` 停用。
  final int? available;
  final int? createTimeMs;

  bool get isForbidden => (forbidden ?? 0) == 1;

  /// 原始 `available==1`（停用态）；黑名单是否生效请用 [isBlackActive]。
  bool get isAvailable => (available ?? 0) == 1;

  /// 黑名单条目是否正在拦截（`available==0`）。
  bool get isBlackActive => (available ?? 1) == 0;

  factory OpsIpRow.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}');
    }

    return OpsIpRow(
      ip: '${json['ip'] ?? ''}',
      tag: json['tag']?.toString(),
      description: json['description']?.toString(),
      forbidden: asInt(json['forbidden']),
      available: asInt(json['available']),
      createTimeMs: asInt(json['createTime']),
    );
  }
}

class OpsIpPage {
  const OpsIpPage({
    required this.count,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.list,
  });

  final int count;
  final int page;
  final int limit;
  final bool hasMore;
  final List<OpsIpRow> list;

  factory OpsIpPage.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}') ?? fallback;
    }

    final raw = json['list'];
    final rows = <OpsIpRow>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          rows.add(OpsIpRow.fromJson(e));
        } else if (e is Map) {
          rows.add(OpsIpRow.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final page = asInt(json['page'], 1);
    final limit = asInt(json['limit'], 20);
    final count = asInt(json['count'], rows.length);
    final hasMore = json['hasMore'] == true || page * limit < count;
    return OpsIpPage(
      count: count,
      page: page,
      limit: limit,
      hasMore: hasMore,
      list: rows,
    );
  }
}

class OpsCredentialBundle {
  const OpsCredentialBundle({
    required this.siteId,
    required this.certId,
    required this.baseUrl,
    required this.clientPrivateKeyPem,
    required this.clientPublicKeyPem,
    required this.serverPublicKey,
    this.serverFingerprint,
    this.label,
  });

  final String siteId;
  final String certId;
  final String baseUrl;
  final String clientPrivateKeyPem;
  final String clientPublicKeyPem;
  final String serverPublicKey;
  final String? serverFingerprint;
  final String? label;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'siteId': siteId,
        'certId': certId,
        'baseUrl': baseUrl,
        'clientPrivateKeyPem': clientPrivateKeyPem,
        'clientPublicKeyPem': clientPublicKeyPem,
        'serverPublicKey': serverPublicKey,
        'serverFingerprint': serverFingerprint,
        'label': label,
      };

  factory OpsCredentialBundle.fromJson(Map<String, dynamic> json) {
    return OpsCredentialBundle(
      siteId: '${json['siteId'] ?? ''}',
      certId: '${json['certId'] ?? ''}',
      baseUrl: '${json['baseUrl'] ?? ''}',
      clientPrivateKeyPem: '${json['clientPrivateKeyPem'] ?? ''}',
      clientPublicKeyPem: '${json['clientPublicKeyPem'] ?? ''}',
      serverPublicKey: '${json['serverPublicKey'] ?? ''}',
      serverFingerprint: json['serverFingerprint']?.toString(),
      label: json['label']?.toString(),
    );
  }
}
