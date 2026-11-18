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
