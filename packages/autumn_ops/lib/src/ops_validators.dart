import 'ops_endpoint.dart';

/// 输入校验结果：`error == null` 表示通过。
class OpsValidateResult {
  const OpsValidateResult.ok() : error = null;
  const OpsValidateResult.fail(this.error);

  final String? error;
  bool get ok => error == null;
}

/// 运维 App 表单输入格式校验（中文错误文案）。
class OpsValidators {
  OpsValidators._();

  static final RegExp _ipv4 = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}'
    r'(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$',
  );

  static final RegExp _ipv4Cidr = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}'
    r'(?:25[0-5]|2[0-4]\d|[01]?\d\d?)/(?:[0-9]|[12]\d|3[0-2])$',
  );

  /// 站点显示名称。
  static OpsValidateResult siteTitle(String raw) {
    final s = raw.trim();
    if (s.length > 64) {
      return const OpsValidateResult.fail('显示名称不能超过 64 个字符');
    }
    return const OpsValidateResult.ok();
  }

  /// 域名 / IP / 完整 URL。
  static OpsValidateResult siteEndpoint(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.fail('请填写域名或 IP');
    }
    if (s.length > 256) {
      return const OpsValidateResult.fail('地址过长');
    }
    if (RegExp(r'\s').hasMatch(s)) {
      return const OpsValidateResult.fail('地址不能包含空格');
    }
    final plan = OpsEndpoint.resolve(s);
    if (plan.isEmpty) {
      return const OpsValidateResult.fail('地址格式无效，请填写域名、IP 或 http(s) 完整地址');
    }
    if (plan.kind == OpsEndpointKind.explicit) {
      final uri = Uri.tryParse(plan.candidates.first);
      if (uri == null || uri.host.isEmpty) {
        return const OpsValidateResult.fail('URL 格式无效');
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return const OpsValidateResult.fail('仅支持 http 或 https 协议');
      }
    }
    return const OpsValidateResult.ok();
  }

  /// 首次入驻口令。
  static OpsValidateResult enrollSecret(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.fail('请填写入驻口令');
    }
    if (s.length < 8) {
      return const OpsValidateResult.fail('入驻口令过短，请完整复制日志中的口令');
    }
    if (s.length > 512) {
      return const OpsValidateResult.fail('入驻口令过长');
    }
    if (RegExp(r'\s').hasMatch(s)) {
      return const OpsValidateResult.fail('入驻口令不能包含空格，请勿复制多余空白');
    }
    return const OpsValidateResult.ok();
  }

  /// 认领码。
  static OpsValidateResult claimSecret(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.fail('请填写认领码');
    }
    if (s.length < 8) {
      return const OpsValidateResult.fail('认领码过短，请完整粘贴');
    }
    if (s.length > 512) {
      return const OpsValidateResult.fail('认领码过长');
    }
    if (RegExp(r'\s').hasMatch(s)) {
      return const OpsValidateResult.fail('认领码不能包含空格');
    }
    return const OpsValidateResult.ok();
  }

  /// 清除确认令牌。
  static OpsValidateResult clearToken(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.fail('请填写清除确认令牌');
    }
    if (s.length < 4) {
      return const OpsValidateResult.fail('清除确认令牌过短');
    }
    if (s.length > 256) {
      return const OpsValidateResult.fail('清除确认令牌过长');
    }
    if (RegExp(r'\s').hasMatch(s)) {
      return const OpsValidateResult.fail('清除确认令牌不能包含空格');
    }
    return const OpsValidateResult.ok();
  }

  /// 管理 IP / 白名单 / 黑名单：单 IP 或 IPv4 CIDR（如 192.168.1.0/24）。
  static OpsValidateResult wallIp(String raw, {bool allowCidr = true}) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.fail('请填写 IP 地址');
    }
    if (s.length > 128) {
      return const OpsValidateResult.fail('IP 地址过长');
    }
    if (RegExp(r'\s').hasMatch(s)) {
      return const OpsValidateResult.fail('IP 地址不能包含空格');
    }

    // 去掉 IPv6 方括号
    var host = s;
    if (host.startsWith('[') && host.contains(']')) {
      host = host.substring(1, host.indexOf(']'));
    }

    if (allowCidr && host.contains('/')) {
      if (_ipv4Cidr.hasMatch(host)) {
        return const OpsValidateResult.ok();
      }
      // IPv6 CIDR：前缀 0–128
      final slash = host.lastIndexOf('/');
      final addr = host.substring(0, slash);
      final prefix = host.substring(slash + 1);
      final p = int.tryParse(prefix);
      if (OpsEndpoint.isIpLiteral(addr) && !_ipv4.hasMatch(addr) && p != null && p >= 0 && p <= 128) {
        return const OpsValidateResult.ok();
      }
      return const OpsValidateResult.fail('网段格式无效，示例：192.168.1.0/24');
    }

    if (OpsEndpoint.isIpLiteral(host) || _ipv4.hasMatch(host)) {
      return const OpsValidateResult.ok();
    }
    return const OpsValidateResult.fail('IP 格式无效，请填写 IPv4 / IPv6 地址');
  }

  /// 证书备份分享口令。
  static OpsValidateResult sharePassphrase(String raw) {
    final s = raw; // 口令允许首尾空格以外的内容，但 trim 后判断空
    final t = s.trim();
    if (t.isEmpty) {
      return const OpsValidateResult.fail('请填写分享口令');
    }
    if (t.length < 6) {
      return const OpsValidateResult.fail('分享口令至少 6 位');
    }
    if (t.length > 128) {
      return const OpsValidateResult.fail('分享口令过长');
    }
    return const OpsValidateResult.ok();
  }

  /// 新设备标签。
  static OpsValidateResult deviceLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.ok(); // 允许空，调用方可用默认值
    }
    if (s.length > 64) {
      return const OpsValidateResult.fail('设备标签不能超过 64 个字符');
    }
    return const OpsValidateResult.ok();
  }

  /// 备份密文（导入）。
  static OpsValidateResult backupBlob(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return const OpsValidateResult.fail('请粘贴备份密文');
    }
    if (s.length < 32) {
      return const OpsValidateResult.fail('备份密文过短，请确认完整粘贴');
    }
    if (s.length > 200000) {
      return const OpsValidateResult.fail('备份密文过长');
    }
    return const OpsValidateResult.ok();
  }
}
