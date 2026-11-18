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
    return enrolled;
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

  Future<Map<String, dynamic>> adminIpList() =>
      _authedPost('/ops/api/v1/adminip/list', {});

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

  Future<Map<String, dynamic>> currentIp() =>
      _authedPost('/ops/api/v1/currentIp', {});

  Future<Map<String, dynamic>> ipWhiteList() =>
      _authedPost('/ops/api/v1/ipwhite/list', {});

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

  Future<Map<String, dynamic>> ipBlackList() =>
      _authedPost('/ops/api/v1/ipblack/list', {});

  Future<Map<String, dynamic>> ipBlackAdd(String ip) =>
      _authedPost('/ops/api/v1/ipblack/add', {'ip': ip});

  Future<Map<String, dynamic>> ipBlackRemove(String ip) =>
      _authedPost('/ops/api/v1/ipblack/remove', {'ip': ip});

  Future<Map<String, dynamic>> gateGet() =>
      _authedPost('/ops/api/v1/gate/get', {});

  Future<Map<String, dynamic>> gateSetAdminIpEnable({
    required bool enable,
    String? clearToken,
  }) =>
      _authedPost('/ops/api/v1/gate/setAdminIpEnable', {
        'enable': enable,
        if (clearToken != null && clearToken.isNotEmpty) 'clearToken': clearToken,
      });

  Future<Map<String, dynamic>> certList() =>
      _authedPost('/ops/api/v1/cert/list', {});

  Future<Map<String, dynamic>> certRevoke(String certId) =>
      _authedPost('/ops/api/v1/cert/revoke', {'certId': certId});

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
