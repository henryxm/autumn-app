#import "AutumnOpsProbeOutcome.h"

@implementation AutumnOpsProbeOutcome

+ (instancetype)fromSuccess:(AutumnOpsProbeResult *)r hasLocalCert:(BOOL)hasLocalCert {
  AutumnOpsProbeOutcome *o = [AutumnOpsProbeOutcome new];
  o.result = r;
  if (!r.autumn) {
    o.kind = AutumnOpsProbeKindIncompatible;
    o.message = @"该站点未部署运维证书能力，或 Autumn 版本过旧";
    o.nextStep = @"请升级服务端后再用本客户端管理";
    return o;
  }
  if ([r.opsCert isEqualToString:@"ready"] && hasLocalCert) {
    o.kind = AutumnOpsProbeKindReady;
    o.message = @"本机已有证书，可进入管理";
    o.nextStep = @"打开该站点管理页即可操作";
    return o;
  }
  if (r.enrollAvailable && ([r.opsCert isEqualToString:@"pending"] || [r.opsCert isEqualToString:@"none"])) {
    o.kind = AutumnOpsProbeKindPending;
    o.message = @"站点可首次入驻";
    o.nextStep = @"从服务器控制台日志复制「入驻口令」（OpsEnroll secret=）后完成首次入驻";
    return o;
  }
  if (!r.enrollAvailable && !hasLocalCert) {
    o.kind = AutumnOpsProbeKindNeedReset;
    o.message = @"站点已入驻过，本机没有可用证书";
    o.nextStep = @"若有运维凭证：选「凭证」。若有其它在线设备：用「认领码」。若唯一设备丢失：运维墙重置后再用「首次口令」";
    return o;
  }
  if ([r.opsCert isEqualToString:@"ready"] && !hasLocalCert) {
    o.kind = AutumnOpsProbeKindNeedReset;
    o.message = @"站点已就绪，但本机无证书";
    o.nextStep = @"有凭证则导入；否则用认领码；都没有则需运维墙重置后再入驻";
    return o;
  }
  o.kind = AutumnOpsProbeKindReady;
  o.message = [NSString stringWithFormat:@"站点可达（状态：%@）", r.opsCert];
  return o;
}

+ (instancetype)fromErrorMessage:(NSString *)msg {
  AutumnOpsProbeOutcome *o = [AutumnOpsProbeOutcome new];
  o.message = msg ?: @"网络错误";
  if ([msg containsString:@"未部署"] || [msg containsString:@"版本过旧"] || [msg containsString:@"网页而非接口"]) {
    o.kind = AutumnOpsProbeKindIncompatible;
    o.nextStep = @"请升级或确认服务端运维证书能力已启用";
  } else if ([msg containsString:@"被拒绝"]) {
    o.kind = AutumnOpsProbeKindForbidden;
    o.nextStep = @"检查网关是否剥离了自定义头";
  } else {
    o.kind = AutumnOpsProbeKindNetwork;
    o.nextStep = @"确认域名/IP、端口，以及后台服务是否在线";
  }
  return o;
}

@end
