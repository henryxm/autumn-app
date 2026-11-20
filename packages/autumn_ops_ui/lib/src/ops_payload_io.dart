import 'dart:io';

import 'package:autumn_ops/autumn_ops.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 宿主注入：将 AutumnOps content 发到宿主 IM / 选人流程。
typedef AutumnOpsShareToChat = Future<bool> Function(
  BuildContext context,
  Map<String, dynamic> content,
);

/// 第三方宿主在启动时赋值；未赋值时管理页「分享到聊天」不可用。
abstract final class AutumnOpsShareHooks {
  static AutumnOpsShareToChat? toChat;
}

/// 组装 IM `AutumnOps` content（不发送）。
Future<Map<String, dynamic>> buildAutumnOpsMessageContent({
  required AutumnOpsClient client,
  required String passphrase,
  required OpsSiteEntry site,
}) async {
  final wrapped = await client.exportWrapped(passphrase);
  final blob = OpsValidators.wrappedBlob(wrapped);
  if (!blob.ok) {
    throw StateError(blob.error ?? '运维密文无效');
  }
  return AutumnOpsPayload.toMessageMap(
    wrappedCipher: wrapped,
    baseUrl: site.baseUrl,
    siteId: site.siteId,
    certId: site.certId,
    serverFingerprint: site.serverFingerprint,
  );
}

/// 分享到宿主聊天（依赖 [AutumnOpsShareHooks.toChat]）。
Future<bool> shareAutumnOpsToChat({
  required BuildContext context,
  required AutumnOpsClient client,
  required String passphrase,
  required OpsSiteEntry site,
}) async {
  final hook = AutumnOpsShareHooks.toChat;
  if (hook == null) {
    return false;
  }
  final content = await buildAutumnOpsMessageContent(
    client: client,
    passphrase: passphrase,
    site: site,
  );
  if (!context.mounted) {
    return false;
  }
  return hook(context, content);
}

/// 导出本机运维凭证文件并拉起系统分享（非 IM 入口）。
Future<File> exportAutumnOpsCredentialFile({
  required AutumnOpsClient client,
  required String passphrase,
  required OpsSiteEntry site,
}) async {
  final wrapped = await client.exportWrapped(passphrase);
  final body = AutumnOpsPayload.encodeJson(
    wrappedCipher: wrapped,
    baseUrl: site.baseUrl,
    siteId: site.siteId,
    certId: site.certId,
    serverFingerprint: site.serverFingerprint,
  );
  final dir = await getTemporaryDirectory();
  final safeTitle = (site.title.isEmpty ? 'site' : site.title)
      .replaceAll(RegExp(r'[^\w\u4e00-\u9fff\-]+'), '_');
  final idPart = site.id.length >= 8 ? site.id.substring(0, 8) : site.id;
  final f = File(
    '${dir.path}/autumn-ops-$safeTitle-$idPart.${AutumnOpsPayload.fileExtension}',
  );
  await f.writeAsString(body, flush: true);
  await Share.shareXFiles(
    [XFile(f.path)],
    text:
        'Autumn 运维凭证\n'
        '站点：${site.baseUrl}\n'
        '导入：设分享口令后在运维管理页选择本文件导入；宿主会话请用「分享到聊天」。\n'
        '口令不会写进文件。',
  );
  return f;
}

/// 选择本机运维凭证文件并解析（不解密）。
Future<AutumnOpsPickResult> pickAutumnOpsCredentialFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: [AutumnOpsPayload.fileExtension, 'json'],
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) {
    return const AutumnOpsPickResult.cancelled();
  }
  final f = result.files.single;
  String? raw;
  if (f.bytes != null && f.bytes!.isNotEmpty) {
    raw = String.fromCharCodes(f.bytes!);
  } else if (f.path != null && f.path!.isNotEmpty) {
    raw = await File(f.path!).readAsString();
  }
  if (raw == null || raw.trim().isEmpty) {
    return const AutumnOpsPickResult.fail('无法读取所选文件');
  }
  final parsed = AutumnOpsPayload.parse(raw);
  if (!parsed.ok) {
    return AutumnOpsPickResult.fail(parsed.error ?? '运维凭证无效');
  }
  return AutumnOpsPickResult.ok(
    payload: parsed.payload!,
    displayName: f.name,
  );
}

class AutumnOpsPickResult {
  const AutumnOpsPickResult._({
    this.payload,
    this.displayName,
    this.error,
    this.cancelled = false,
  });

  const AutumnOpsPickResult.ok({
    required AutumnOpsPayload payload,
    required String displayName,
  }) : this._(payload: payload, displayName: displayName);

  const AutumnOpsPickResult.fail(String error) : this._(error: error);

  const AutumnOpsPickResult.cancelled() : this._(cancelled: true);

  final AutumnOpsPayload? payload;
  final String? displayName;
  final String? error;
  final bool cancelled;

  bool get ok => payload != null && error == null && !cancelled;
}
