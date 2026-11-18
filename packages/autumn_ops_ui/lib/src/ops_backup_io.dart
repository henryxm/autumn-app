import 'dart:io';

import 'package:autumn_ops/autumn_ops.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 导出结构化 `.ops` 并拉起系统分享。
Future<File> exportOpsBackupFile({
  required AutumnOpsClient client,
  required String passphrase,
  required OpsSiteEntry site,
}) async {
  final wrapped = await client.exportWrapped(passphrase);
  final body = OpsBackupFile.encode(
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
    '${dir.path}/autumn-ops-$safeTitle-$idPart.${OpsBackupFile.fileExtension}',
  );
  await f.writeAsString(body, flush: true);
  await Share.shareXFiles(
    [XFile(f.path)],
    text:
        'Autumn 运维证书备份（.ops）\n'
        '站点：${site.baseUrl}\n'
        '导入：新手机 Autumn 运维 →「+」→ 探测同一地址 →「换机备份」→ 选本文件并填导出时的分享口令。\n'
        '口令不会写进文件；丢失口令则无法解开。',
  );
  return f;
}

/// 选择 `.ops` 备份文件并解析（不解密；解密仍须分享口令）。
Future<OpsBackupPickResult> pickOpsBackupFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: [OpsBackupFile.fileExtension, 'json', 'txt'],
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) {
    return const OpsBackupPickResult.cancelled();
  }
  final f = result.files.single;
  String? raw;
  if (f.bytes != null && f.bytes!.isNotEmpty) {
    raw = String.fromCharCodes(f.bytes!);
  } else if (f.path != null && f.path!.isNotEmpty) {
    raw = await File(f.path!).readAsString();
  }
  if (raw == null || raw.trim().isEmpty) {
    return const OpsBackupPickResult.fail('无法读取所选文件');
  }
  final parsed = OpsBackupFile.parse(raw);
  if (!parsed.ok) {
    return OpsBackupPickResult.fail(parsed.error ?? '备份文件无效');
  }
  return OpsBackupPickResult.ok(
    file: parsed.file!,
    displayName: f.name,
  );
}

class OpsBackupPickResult {
  const OpsBackupPickResult._({
    this.file,
    this.displayName,
    this.error,
    this.cancelled = false,
  });

  const OpsBackupPickResult.ok({
    required OpsBackupFile file,
    required String displayName,
  }) : this._(file: file, displayName: displayName);

  const OpsBackupPickResult.fail(String error) : this._(error: error);

  const OpsBackupPickResult.cancelled() : this._(cancelled: true);

  final OpsBackupFile? file;
  final String? displayName;
  final String? error;
  final bool cancelled;

  bool get ok => file != null && error == null && !cancelled;
}
