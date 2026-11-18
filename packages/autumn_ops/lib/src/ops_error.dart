import 'package:dio/dio.dart';

/// 将网络/运维 API 异常转成面向用户的中文说明（避免直接展示 DioException 原文）。
class OpsErrorMessage {
  OpsErrorMessage._();

  /// 简短主文案（适合 SnackBar / 状态条）。
  static String of(Object error) => describe(error).message;

  /// 主文案 + 可选下一步提示。
  static ({String message, String? nextStep}) describe(Object error) {
    if (error is DioException) {
      return _fromDio(error);
    }
    final raw = error.toString();
    if (_looksOffline(raw)) {
      return (
        message: '无法连接后台，服务可能未启动或不在线',
        nextStep: '请确认 Autumn 已启动，并检查地址、端口与本机网络',
      );
    }
    if (raw.contains('HandshakeException') || raw.contains('CERTIFICATE_VERIFY_FAILED')) {
      return (
        message: '安全连接失败',
        nextStep: '请检查站点是否强制 HTTPS，或证书是否有效',
      );
    }
    if (raw.contains('TimeoutException') || raw.toLowerCase().contains('timed out')) {
      return (
        message: '连接超时，后台可能未响应',
        nextStep: '请稍后重试，或确认服务已启动',
      );
    }
    if (raw.contains('FormatException') || raw.contains('empty response')) {
      return (
        message: '后台返回异常，站点可能不是可用的 Autumn 运维接口',
        nextStep: null,
      );
    }
    if (raw.startsWith('StateError: ')) {
      return (message: _mapBizMessage(raw.substring('StateError: '.length).trim()), nextStep: null);
    }
    if (raw.startsWith('Bad state: ')) {
      return (message: _mapBizMessage(raw.substring('Bad state: '.length).trim()), nextStep: null);
    }
    final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length > 120) {
      return (message: '${compact.substring(0, 117)}…', nextStep: null);
    }
    return (message: compact.isEmpty ? '操作失败' : compact, nextStep: null);
  }

  /// 一行或多行展示：有 nextStep 时拼在后面。
  static String display(Object error) {
    final d = describe(error);
    if (d.nextStep == null || d.nextStep!.isEmpty) return d.message;
    return '${d.message}\n${d.nextStep}';
  }

  static ({String message, String? nextStep}) _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return (
          message: '连接超时，后台可能未启动或网络不稳定',
          nextStep: '请确认服务已启动后重试',
        );
      case DioExceptionType.connectionError:
        return (
          message: '无法连接后台，服务可能未启动或不在线',
          nextStep: '请检查站点地址、端口，以及本机是否可达该网络',
        );
      case DioExceptionType.badCertificate:
        return (
          message: 'HTTPS 证书校验失败',
          nextStep: '请检查站点证书，或改用正确的协议与地址',
        );
      case DioExceptionType.cancel:
        return (message: '请求已取消', nextStep: null);
      case DioExceptionType.badResponse:
        return _fromStatus(e.response?.statusCode, e.response?.data);
      case DioExceptionType.unknown:
        final blob = '${e.message} ${e.error ?? ''}';
        if (_looksOffline(blob)) {
          return (
            message: '无法连接后台，服务可能未启动或不在线',
            nextStep: '请确认 Autumn 已启动后再试',
          );
        }
        if (e.error != null) {
          final nested = describe(e.error!);
          // 仅当内层已映射为可读中文时采用，避免再抛出原始 toString
          if (nested.message != e.error.toString() && !_isRawDump(nested.message)) {
            return nested;
          }
        }
        return (
          message: '网络异常，暂时无法访问后台',
          nextStep: '请检查网络后重试',
        );
    }
  }

  static bool _isRawDump(String msg) {
    final s = msg.toLowerCase();
    return s.contains('dioexception') ||
        s.contains('socketexception') ||
        s.contains('instance of');
  }

  static ({String message, String? nextStep}) _fromStatus(int? code, Object? data) {
    if (code == 404) {
      return (
        message: '未找到运维接口，站点可能未部署或版本过旧',
        nextStep: null,
      );
    }
    if (code == 403) {
      return (
        message: '请求被拒绝',
        nextStep: '请检查权限、探测头或管理 IP 门禁设置',
      );
    }
    if (code == 401) {
      return (message: '会话已失效，请刷新后重试', nextStep: null);
    }
    if (code == 502 || code == 503 || code == 504) {
      return (
        message: '后台暂时不可用（网关或服务未就绪）',
        nextStep: '请稍后重试，或确认 Autumn 进程已启动',
      );
    }
    if (data is String && data.contains('<html')) {
      return (
        message: '后台返回了网页而非接口数据，服务可能未正确部署',
        nextStep: null,
      );
    }
    if (data is Map && data['msg'] != null) {
      return (message: _mapBizMessage('${data['msg']}'), nextStep: null);
    }
    if (code != null) {
      return (message: '后台返回错误（HTTP $code）', nextStep: null);
    }
    return (message: '后台返回异常', nextStep: null);
  }

  static bool _looksOffline(String raw) {
    final s = raw.toLowerCase();
    return s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('network is unreachable') ||
        s.contains('failed host lookup') ||
        s.contains('nodename nor servname') ||
        s.contains('socketexception') ||
        s.contains('connection errored') ||
        s.contains('connection closed') ||
        s.contains('broken pipe') ||
        s.contains('errno = 61') ||
        s.contains('errno = 111') ||
        s.contains('timed out') ||
        s.contains('timeout');
  }

  static String _mapBizMessage(String msg) {
    final raw = msg.trim();
    final lower = raw.toLowerCase();
    if (raw.contains('服务端尚未配置清除确认令牌') || raw.contains('尚未配置清除确认令牌')) {
      return '服务端尚未配置清除确认令牌，请在本页直接填写并保存以完成配置';
    }
    if (raw.contains('原清除确认令牌不正确')) {
      return '原清除确认令牌不正确，修改失败';
    }
    if (raw.contains('清除确认令牌长度')) {
      return '清除确认令牌长度须为 4～256 个字符';
    }
    if (raw.contains('清除确认令牌不能包含空白')) {
      return '清除确认令牌不能包含空格';
    }
    if (raw.contains('清除确认令牌不正确') ||
        (lower.contains('cleartoken') &&
            (raw.contains('不正确') || raw.contains('须提供正确')))) {
      return '清除确认令牌不正确，请核对后重试';
    }
    if (raw.contains('请填写清除确认令牌') || raw.contains('clearToken 不能为空')) {
      return '请填写清除确认令牌';
    }
    if (raw.contains('须提供正确 clearToken')) {
      return '清除确认令牌不正确，请到系统加固 / 安全配置中核对后重试';
    }
    if (msg.contains('not enrolled')) {
      return '本机尚未入驻，请先添加站点并完成入驻';
    }
    if (msg.contains('ops session empty')) {
      return '建立运维会话失败，请刷新后重试';
    }
    if (msg.contains('empty response')) {
      return '后台无有效响应，服务可能未就绪';
    }
    // 剥离常见技术前缀
    var cleaned = raw
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .replaceFirst(RegExp(r'^Exception:\s*'), '');
    // 形如 "xxx (403)" → 保留业务句，去掉尾部状态码噪音时可保留
    cleaned = cleaned.replaceFirst(RegExp(r'\s*\(\d{3}\)\s*$'), '');
    if (_isRawDump(cleaned) || cleaned.toLowerCase().contains('dioexception')) {
      return '操作失败，请检查网络或后台服务后重试';
    }
    return cleaned.isEmpty ? '操作失败' : cleaned;
  }
}
