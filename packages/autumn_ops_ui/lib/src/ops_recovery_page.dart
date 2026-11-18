import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 唯一设备丢失 / 自吊销 / 卸装无备份后的恢复说明。
class OpsRecoveryPage extends StatelessWidget {
  const OpsRecoveryPage({super.key, this.siteTitle, this.baseUrl});

  final String? siteTitle;
  final String? baseUrl;

  static const _sql = "UPDATE sys_config SET param_value = '{}' WHERE param_key = 'SECURITY_OPS_CERT_CONFIG';";

  @override
  Widget build(BuildContext context) {
    final title = siteTitle == null || siteTitle!.isEmpty
        ? '恢复运维证书'
        : '恢复：$siteTitle';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (baseUrl != null && baseUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('站点：$baseUrl', style: const TextStyle(color: Colors.black54)),
            ),
          const Text(
            '本机证书已不可用（清除、卸装或吊销了最后一张有效证）。'
            '服务端不会通过网络下发私钥，需重新打开入驻窗口。',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 20),
          _step(
            1,
            '优先：运维墙重置',
            '用超级管理员账号登录该站运维墙，打开运维证书状态，'
            '填写系统加固中的「清除确认令牌」，执行「重置运维证书」。',
          ),
          _step(
            2,
            '复制新的入驻口令',
            '重置成功后，查看服务器控制台日志中的一行：OpsEnroll secret=…'
            '（仅打印一次，请立即复制口令部分）。',
          ),
          _step(
            3,
            '在本 App 重新入驻',
            '返回「添加站点」→ 填写同一地址 → 探测 → 粘贴新的入驻口令 → 入驻。',
          ),
          const SizedBox(height: 12),
          const Text('若 IP 已锁死、无法登录运维墙', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            '在数据库执行下列语句后重启 Autumn，日志会出现新的入驻口令；'
            '仅重启不够（库中仍有已入驻设备时不会重发临时口令）。',
            style: TextStyle(height: 1.4, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(_sql, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: _sql));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制数据库语句')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('复制数据库语句'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  static Widget _step(int n, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, child: Text('$n', style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(height: 1.4, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
