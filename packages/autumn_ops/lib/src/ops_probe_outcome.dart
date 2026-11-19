import 'ops_error.dart';
import 'ops_models.dart';

enum OpsProbeKind {
  network,
  incompatible,
  forbidden,
  pending,
  ready,
  needReset,
}

class OpsProbeOutcome {
  const OpsProbeOutcome({
    required this.kind,
    required this.message,
    this.nextStep,
    this.result,
  });

  final OpsProbeKind kind;
  final String message;
  /// 给用户的下一步操作提示（可空）。
  final String? nextStep;
  final OpsProbeResult? result;

  static OpsProbeOutcome fromSuccess(OpsProbeResult r, {bool hasLocalCert = false}) {
    if (!r.autumn) {
      return const OpsProbeOutcome(
        kind: OpsProbeKind.incompatible,
        message: '该站点未部署运维证书能力，或 Autumn 版本过旧',
        nextStep: '请升级服务端后再用本客户端管理',
      );
    }
    if (r.opsCert == 'ready' && hasLocalCert) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.ready,
        message: '本机已有证书，可进入管理',
        nextStep: '打开该站点管理页即可操作',
        result: r,
      );
    }
    if (r.enrollAvailable && (r.opsCert == 'pending' || r.opsCert == 'none')) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.pending,
        message: '站点可首次入驻',
        nextStep: '从服务器控制台日志复制「入驻口令」（OpsEnroll secret=）后完成首次入驻',
        result: r,
      );
    }
    if (!r.enrollAvailable && !hasLocalCert) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.needReset,
        message: '站点已入驻过，本机没有可用证书',
        nextStep:
            '若有运维凭证：选「凭证」并选择文件或打开 AutumnOps 消息。若有其它在线设备：用「认领码」（文字）。若唯一设备丢失且无凭证：运维墙重置后再用「首次口令」',
        result: r,
      );
    }
    if (r.opsCert == 'ready' && !hasLocalCert) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.needReset,
        message: '站点已就绪，但本机无证书',
        nextStep: '有凭证则选「凭证」选文件或打开 AutumnOps 消息；否则用「认领码」；都没有则需运维墙重置后再入驻',
        result: r,
      );
    }
    return OpsProbeOutcome(
      kind: OpsProbeKind.ready,
      message: '站点可达（状态：${r.opsCert}）',
      result: r,
    );
  }

  static OpsProbeOutcome fromError(Object e) {
    final d = OpsErrorMessage.describe(e);
    final msg = d.message;
    if (msg.contains('未部署') ||
        msg.contains('版本过旧') ||
        msg.contains('网页而非接口') ||
        msg.contains('不是可用的 Autumn')) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.incompatible,
        message: msg,
        nextStep: d.nextStep ?? '请升级或确认服务端运维证书能力已启用',
      );
    }
    if (msg.contains('被拒绝')) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.forbidden,
        message: msg,
        nextStep: d.nextStep ?? '检查网关是否剥离了自定义头',
      );
    }
    return OpsProbeOutcome(
      kind: OpsProbeKind.network,
      message: msg,
      nextStep: d.nextStep ?? '确认域名/IP、端口，以及后台服务是否在线',
    );
  }
}
