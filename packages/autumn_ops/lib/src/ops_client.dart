import 'package:dio/dio.dart';

import 'ops_crypto.dart';
import 'ops_models.dart';
import 'ops_probe.dart';
import 'ops_probe_outcome.dart';
import 'ops_store.dart';

/// Autumn `/ops/api/v1` client. Private keys stay on device via [OpsStore].
class AutumnOpsClient {
  AutumnOpsClient({
    required this.baseUrl,
    required this.store,
    Dio? dio,
  }) : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        ));

  final String baseUrl;
  final OpsStore store;
  final Dio _dio;

  String? _sessionId;
  OpsCredentialBundle? _bundle;

  String get root => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  Future<OpsProbeResult> probe() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '$root/ops/api/v1/probe',
      data: const {},
      options: Options(headers: {AutumnOpsProbe.header: AutumnOpsProbe.token}),
    );
    return OpsProbeResult.fromJson(_unwrap(res.data));
  }

  Future<OpsProbeOutcome> probeOutcome({bool hasLocalCert = false}) async {
    try {
      final r = await probe();
      return OpsProbeOutcome.fromSuccess(r, hasLocalCert: hasLocalCert);
    } catch (e) {
      return OpsProbeOutcome.fromError(e);
    }
  }

  Future<OpsEnrollResult> enroll({
    required String secret,
    String label = 'flutter',
  }) async {
    final pair = OpsCrypto.generateRsa2048();
    final pubPem = OpsCrypto.publicKeyToPem(pair.publicKey);
    final priPem = OpsCrypto.privateKeyToPem(pair.privateKey);
    final res = await _dio.post<Map<String, dynamic>>(
      '$root/ops/api/v1/enroll',
      data: {
        'secret': secret,
        'clientPublicKey': OpsCrypto.stripPem(pubPem),
        'label': label,
      },
    );
    final enrolled = OpsEnrollResult.fromJson(_unwrap(res.data));
    await _persistEnrolled(enrolled, pubPem, priPem, label);
    return enrolled;
  }

  /// 新设备：凭已登录设备签发的认领码入驻（本地生成独立密钥对）。
  Future<OpsEnrollResult> claim({
    required String claimSecret,
    String label = 'flutter',
  }) async {
    final pair = OpsCrypto.generateRsa2048();
    final pubPem = OpsCrypto.publicKeyToPem(pair.publicKey);
    final priPem = OpsCrypto.privateKeyToPem(pair.privateKey);
    final res = await _dio.post<Map<String, dynamic>>(
      '$root/ops/api/v1/cert/claim',
      data: {
        'claimSecret': claimSecret,
        'clientPublicKey': OpsCrypto.stripPem(pubPem),
        'label': label,
      },
    );
    final enrolled = OpsEnrollResult.fromJson(_unwrap(res.data));
    await _persistEnrolled(enrolled, pubPem, priPem, label);
    return enrolled;
  }

  Future<void> _persistEnrolled(
    OpsEnrollResult enrolled,
    String pubPem,
    String priPem,
    String label,
  ) async {
    final bundle = OpsCredentialBundle(
      siteId: enrolled.siteId,
      certId: enrolled.certId,
      baseUrl: root,
      clientPrivateKeyPem: priPem,
      clientPublicKeyPem: pubPem,
      serverPublicKey: enrolled.serverPublicKey,
      serverFingerprint: enrolled.serverFingerprint,
      label: label,
    );
    await store.save(bundle);
    _bundle = bundle;
    _sessionId = null;
  }

  Future<void> ensureSession() async {
    final bundle = await _loadBundle();
    final challenge = await _dio.post<Map<String, dynamic>>(
      '$root/ops/api/v1/challenge',
      data: {'certId': bundle.certId},
    );
    final nonce = '${_unwrap(challenge.data)['nonce'] ?? ''}';
    final privateKey = OpsCrypto.loadPrivateKey(bundle.clientPrivateKeyPem);
    final signature = OpsCrypto.signSha256Rsa(privateKey, nonce);
    final aesKey = OpsCrypto.randomAesKeyBase64();
    final aesIv = OpsCrypto.randomIvBase64();
    final serverPub = OpsCrypto.loadPublicKey(bundle.serverPublicKey);
    final wrapped = OpsCrypto.rsaEncryptToBase64(serverPub, aesKey);
    final sessionRes = await _dio.post<Map<String, dynamic>>(
      '$root/ops/api/v1/session',
      data: {
        'certId': bundle.certId,
        'nonce': nonce,
        'signature': signature,
        'aesKeyWrapped': wrapped,
        'aesIv': aesIv,
      },
    );
    _sessionId = '${_unwrap(sessionRes.data)['sessionId'] ?? ''}';
    if (_sessionId == null || _sessionId!.isEmpty) {
      throw StateError('ops session empty');
    }
  }

  Future<OpsIpPage> adminIpList({int page = 1, int limit = 20}) async {
    final data = await _authedPost('/ops/api/v1/adminip/list', {
      'page': page,
      'limit': limit,
    });
    return OpsIpPage.fromJson(data);
  }

  Future<Map<String, dynamic>> adminIpAdd({String? ip, bool claimCurrent = false}) =>
      _authedPost('/ops/api/v1/adminip/add', {
        if (ip != null) 'ip': ip,
        'claimCurrent': claimCurrent,
      });

  Future<Map<String, dynamic>> adminIpRemove(String ip, {String? clearToken}) =>
      _authedPost('/ops/api/v1/adminip/remove', {
        'ip': ip,
        if (clearToken != null && clearToken.isNotEmpty) 'clearToken': clearToken,
      });

  Future<Map<String, dynamic>> adminIpSetForbidden(String ip, {required bool forbidden}) =>
      _authedPost('/ops/api/v1/adminip/setForbidden', {
        'ip': ip,
        'forbidden': forbidden ? 1 : 0,
      });

  Future<Map<String, dynamic>> currentIp() =>
      _authedPost('/ops/api/v1/currentIp', {});

  Future<OpsIpPage> ipWhiteList({int page = 1, int limit = 20}) async {
    final data = await _authedPost('/ops/api/v1/ipwhite/list', {
      'page': page,
      'limit': limit,
    });
    return OpsIpPage.fromJson(data);
  }

  Future<Map<String, dynamic>> ipWhiteAdd({String? ip, bool claimCurrent = false}) =>
      _authedPost('/ops/api/v1/ipwhite/add', {
        if (ip != null) 'ip': ip,
        'claimCurrent': claimCurrent,
      });

  Future<Map<String, dynamic>> ipWhiteRemove(String ip, {String? clearToken}) =>
      _authedPost('/ops/api/v1/ipwhite/remove', {
        'ip': ip,
        if (clearToken != null && clearToken.isNotEmpty) 'clearToken': clearToken,
      });

  Future<Map<String, dynamic>> ipWhiteSetForbidden(String ip, {required bool forbidden}) =>
      _authedPost('/ops/api/v1/ipwhite/setForbidden', {
        'ip': ip,
        'forbidden': forbidden ? 1 : 0,
      });

  Future<OpsIpPage> ipBlackList({int page = 1, int limit = 20}) async {
    final data = await _authedPost('/ops/api/v1/ipblack/list', {
      'page': page,
      'limit': limit,
    });
    return OpsIpPage.fromJson(data);
  }

  Future<Map<String, dynamic>> ipBlackAdd(String ip) =>
      _authedPost('/ops/api/v1/ipblack/add', {'ip': ip});

  Future<Map<String, dynamic>> ipBlackRemove(String ip) =>
      _authedPost('/ops/api/v1/ipblack/remove', {'ip': ip});

  /// [available]：`0` 生效拦截，`1` 停用（与 wall 一致）。
  Future<Map<String, dynamic>> ipBlackSetAvailable(String ip, {required int available}) =>
      _authedPost('/ops/api/v1/ipblack/setAvailable', {
        'ip': ip,
        'available': available,
      });

  Future<int> ipBlackFirewallCount() async {
    final data = await _authedPost('/ops/api/v1/ipblack/firewallCount/get', {});
    final v = data['firewallCount'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  Future<int> ipBlackSetFirewallCount(int count) async {
    final data = await _authedPost('/ops/api/v1/ipblack/firewallCount/set', {
      'count': count,
    });
    final v = data['firewallCount'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? count;
  }

  Future<Map<String, dynamic>> gateGet() =>
      _authedPost('/ops/api/v1/gate/get', {});

  /// 运行状态快照（JVM/磁盘/库/防火墙/流量/Redis 等）。
  Future<OpsRuntimeSnapshot> runtimeSnapshot() async {
    final data = await _authedPost('/ops/api/v1/runtime/snapshot', {});
    return OpsRuntimeSnapshot.fromJson(data);
  }

  /// 校验清除确认令牌（无副作用）。
  Future<Map<String, dynamic>> gateVerifyClearToken(String clearToken) =>
      _authedPost('/ops/api/v1/gate/verifyClearToken', {
        'clearToken': clearToken,
      });

  /// 配置或修改清除确认令牌。未配置时可直接设置；已配置须传 [oldClearToken]。
  Future<Map<String, dynamic>> gateSetClearToken(
    String clearToken, {
    String? oldClearToken,
  }) =>
      _authedPost('/ops/api/v1/gate/setClearToken', {
        'clearToken': clearToken,
        if (oldClearToken != null && oldClearToken.isNotEmpty) 'oldClearToken': oldClearToken,
      });

  Future<Map<String, dynamic>> gateSetAdminIpEnable({
    required bool enable,
    String? clearToken,
  }) =>
      _authedPost('/ops/api/v1/gate/setAdminIpEnable', {
        'enable': enable,
        if (clearToken != null && clearToken.isNotEmpty) 'clearToken': clearToken,
      });

  /// 开关公开发现页 `/ops/discover`（不要求 clearToken）。
  Future<Map<String, dynamic>> gateSetDiscoverEnabled({
    required bool enable,
  }) =>
      _authedPost('/ops/api/v1/gate/setDiscoverEnabled', {
        'enable': enable,
      });

  Future<Map<String, dynamic>> certList() =>
      _authedPost('/ops/api/v1/cert/list', {});

  /// 已登录设备签发一次性认领码（明文仅本次返回）。
  Future<OpsClaimIssueResult> certIssue({String label = 'ops-device'}) async {
    final data = await _authedPost('/ops/api/v1/cert/issue', {
      'label': label,
    });
    return OpsClaimIssueResult.fromJson(data);
  }

  Future<OpsRevokeResult> certRevoke(String certId) async {
    final data = await _authedPost('/ops/api/v1/cert/revoke', {'certId': certId});
    return OpsRevokeResult.fromJson(data);
  }

  Future<OpsCredentialBundle?> currentBundle() => store.load();

  Future<String> exportWrapped(String passphrase) async {
    final bundle = await _loadBundle();
    return OpsStore.exportPassphraseWrapped(bundle, passphrase);
  }

  Future<void> importWrapped(String wrappedB64, String passphrase) async {
    final bundle = OpsStore.importPassphraseWrapped(wrappedB64, passphrase);
    await store.save(bundle);
    _bundle = bundle;
    _sessionId = null;
  }

  Future<Map<String, dynamic>> _authedPost(String path, Map<String, dynamic> body) async {
    if (_sessionId == null || _sessionId!.isEmpty) {
      await ensureSession();
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$root$path',
        data: body,
        options: Options(headers: {AutumnOpsProbe.sessionHeader: _sessionId}),
      );
      return _unwrap(res.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _sessionId = null;
        await ensureSession();
        final res = await _dio.post<Map<String, dynamic>>(
          '$root$path',
          data: body,
          options: Options(headers: {AutumnOpsProbe.sessionHeader: _sessionId}),
        );
        return _unwrap(res.data);
      }
      rethrow;
    }
  }

  Future<OpsCredentialBundle> _loadBundle() async {
    _bundle ??= await store.load();
    if (_bundle == null) {
      throw StateError('not enrolled: enroll or import credential first');
    }
    return _bundle!;
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw StateError('empty response');
    }
    final code = body['code'];
    if (code != null && code != 0) {
      throw StateError('${body['msg'] ?? 'ops error'} ($code)');
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
  }
}
