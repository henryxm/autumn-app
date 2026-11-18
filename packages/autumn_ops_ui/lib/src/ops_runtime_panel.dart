import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';

/// 运行状态快照面板：分区展示 + 下拉刷新。
class OpsRuntimePanel extends StatefulWidget {
  const OpsRuntimePanel({
    super.key,
    required this.loadSnapshot,
    this.busy = false,
    this.onBusyChanged,
    this.onToast,
  });

  final Future<OpsRuntimeSnapshot> Function() loadSnapshot;
  final bool busy;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<String>? onToast;

  @override
  State<OpsRuntimePanel> createState() => _OpsRuntimePanelState();
}

class _OpsRuntimePanelState extends State<OpsRuntimePanel> {
  OpsRuntimeSnapshot? _snap;
  String? _error;
  bool _loading = false;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loadedOnce) {
        _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final snap = await widget.loadSnapshot();
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _loadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loadedOnce = true;
      });
      widget.onToast?.call('刷新运行状态失败');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      widget.onBusyChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snap == null
                      ? '下拉刷新获取运行快照'
                      : '采集于 ${_formatTime(snap.collectedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: (_loading || widget.busy) ? null : _refresh,
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ],
          if (snap == null && _loading) ...[
            const SizedBox(height: 48),
            const Center(child: CircularProgressIndicator()),
          ] else if (snap != null) ...[
            _systemCard(snap.system),
            const SizedBox(height: 12),
            _jvmCard(snap.jvm),
            const SizedBox(height: 12),
            _diskCard(snap.disk),
            const SizedBox(height: 12),
            _databaseCard(snap.database),
            const SizedBox(height: 12),
            _firewallCard(snap.firewall),
            const SizedBox(height: 12),
            _trafficCard(snap.traffic),
            const SizedBox(height: 12),
            _redisCard(snap.redis),
            const SizedBox(height: 12),
            _pathsCard(snap.paths),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _systemCard(OpsRuntimeSystem s) {
    if (!s.available) return _naCard('系统与负载', s.error);
    final chips = <Widget>[
      _chip('CPU ${s.availableProcessors} 核'),
      if (s.systemLoadAverage != null && s.systemLoadAverage! >= 0)
        _chip('负载 ${_pctOrNum(s.systemLoadAverage!)}'),
      if (s.processCpuLoad != null) _chip('进程 ${_pct(s.processCpuLoad!)}'),
      if (s.systemCpuLoad != null) _chip('系统 ${_pct(s.systemCpuLoad!)}'),
    ];
    return _card(
      title: '系统与负载',
      body: [
        _kv('主机', s.hostname.isEmpty ? '暂无' : s.hostname),
        _kv('系统', '${s.osName} ${s.osArch} ${s.osVersion}'.trim()),
        if (s.physicalTotalBytes != null && s.physicalTotalBytes! > 0) ...[
          _kv('物理内存', '${_bytes(s.physicalUsedBytes ?? 0)} / ${_bytes(s.physicalTotalBytes!)}'),
          _bar((s.physicalUsedBytes ?? 0) / s.physicalTotalBytes!),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  Widget _jvmCard(OpsRuntimeJvm j) {
    if (!j.available) return _naCard('JVM 内存与线程', j.error);
    final heap = j.heap;
    return _card(
      title: 'JVM 内存与线程',
      body: [
        _kv('Java', j.javaVersion.isEmpty ? '暂无' : j.javaVersion),
        _kv('运行时长', _uptime(j.uptimeMs)),
        if (heap != null) ...[
          _kv('堆内存', '${_bytes(heap.used)} / ${_bytes(heap.max > 0 ? heap.max : heap.committed)}'),
          _bar(heap.usedRatio),
        ],
        if (j.nonHeap != null)
          _kv('非堆', '${_bytes(j.nonHeap!.used)} / ${_bytes(j.nonHeap!.committed)}'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip('线程 ${j.threadLive}'),
            _chip('守护 ${j.threadDaemon}'),
            _chip('峰值 ${j.threadPeak}'),
          ],
        ),
      ],
    );
  }

  Widget _diskCard(OpsRuntimeDisk d) {
    if (!d.available) return _naCard('磁盘', d.error);
    if (d.volumes.isEmpty) return _naCard('磁盘', '暂无卷信息');
    return _card(
      title: '磁盘',
      body: [
        for (final v in d.volumes) ...[
          _kv(_diskLabel(v.name), v.available
              ? '${_bytes(v.usedBytes)} / ${_bytes(v.totalBytes)}'
              : (v.error ?? '暂无')),
          if (v.available) _bar(v.usedRatio),
          Text(
            v.path,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _databaseCard(OpsRuntimeDatabase db) {
    if (!db.available) return _naCard('数据库', db.error);
    return _card(
      title: '数据库',
      body: [
        _kv('引擎', db.productName.isEmpty ? '暂无' : '${db.productName} ${db.productVersion}'.trim()),
        if (db.url.isNotEmpty) _kv('连接', db.url),
        _kv('连接池', db.poolType.isEmpty ? '暂无' : db.poolType),
        if (db.maxActive != null)
          _kv('活跃连接', '${db.activeCount ?? 0} / ${db.maxActive}（池中 ${db.poolingCount ?? 0}）'),
        if (db.maxActive != null && db.maxActive! > 0)
          _bar(((db.activeCount ?? 0) / db.maxActive!).clamp(0.0, 1.0)),
        _kv(
          '表数量',
          db.tableCount == null
              ? '暂无'
              : (db.tableCount! < 0 ? (db.tableCountError ?? '暂无') : '${db.tableCount}'),
        ),
      ],
    );
  }

  Widget _firewallCard(OpsRuntimeFirewall f) {
    if (!f.available) return _naCard('防火墙与可疑 IP', f.error);
    return _card(
      title: '防火墙与可疑 IP',
      body: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip(f.adminIpEnable ? '管理IP开' : '管理IP关'),
            _chip(f.shieldAttack ? '攻击模式开' : '攻击模式关'),
            _chip('管理 ${f.adminIpCount}'),
            _chip('白名单 ${f.ipWhiteCount}'),
            _chip('黑名单 ${f.ipBlackCount}'),
            _chip('阈值 ${f.firewallCount}'),
            _chip('内存拦截 ${f.shieldAllowedIpCount}'),
          ],
        ),
        if (f.shieldAllowedIpSample.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('内存拦截样本', style: _sectionHintStyle()),
          ...f.shieldAllowedIpSample.take(20).map(
                (ip) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(ip, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                ),
              ),
        ],
        if (f.blackTopToday.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('今日黑名单命中 Top', style: _sectionHintStyle()),
          ...f.blackTopToday.map(
            (h) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(h.ip, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                  ),
                  Text('今日 ${h.today}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _trafficCard(OpsRuntimeTraffic t) {
    if (!t.available) return _naCard('访问与吞吐', t.error);
    return _card(
      title: '访问与吞吐',
      body: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _chip('请求总量 ${t.requestTotal}'),
            _chip('近 60s ≈ ${t.approxQps.toStringAsFixed(2)} QPS'),
            if (t.pageViewToday != null) _chip('今日 PV ${t.pageViewToday}'),
            if (t.uniqueVisitorToday != null) _chip('今日 UV ${t.uniqueVisitorToday}'),
          ],
        ),
        if (t.visitLogError != null) ...[
          const SizedBox(height: 8),
          Text('访问日志：${t.visitLogError}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }

  Widget _redisCard(OpsRuntimeRedis r) {
    if (!r.enabled) return _naCard('Redis', '未启用');
    if (!r.available) return _naCard('Redis', r.error ?? '暂无');
    return _card(
      title: 'Redis',
      body: [
        _kv('版本', r.version ?? '暂无'),
        _kv('客户端', r.connectedClients ?? '暂无'),
        _kv('内存', r.usedMemory ?? (r.usedMemoryBytes != null ? _bytes(r.usedMemoryBytes!) : '暂无')),
        _kv('键数量', r.keyCount?.toString() ?? '暂无'),
      ],
    );
  }

  Widget _pathsCard(OpsRuntimePaths p) {
    if (!p.available) return _naCard('目录路径', p.error);
    if (p.items.isEmpty) return _naCard('目录路径', '暂无');
    return _card(
      title: '目录路径',
      body: [
        for (final i in p.items) _kv(i.label, i.path.isEmpty ? '暂无' : i.path),
      ],
    );
  }

  Widget _naCard(String title, String? reason) {
    return _card(
      title: title,
      body: [
        Text(
          reason == null || reason.isEmpty ? '暂无' : reason,
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _card({required String title, required List<Widget> body}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...body,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: SelectableText(v, style: const TextStyle(fontSize: 13, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _bar(double ratio) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio.clamp(0.0, 1.0),
          minHeight: 8,
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  TextStyle _sectionHintStyle() => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  static String _diskLabel(String name) {
    switch (name) {
      case 'workdir':
        return '工作目录';
      case 'temp':
        return '临时目录';
      case 'backup':
        return '备份目录';
      default:
        return name;
    }
  }

  static String _formatTime(int ms) {
    if (ms <= 0) return '未知';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static String _uptime(int ms) {
    if (ms <= 0) return '暂无';
    final s = ms ~/ 1000;
    final d = s ~/ 86400;
    final h = (s % 86400) ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (d > 0) return '$d天 $h时 $m分';
    if (h > 0) return '$h时 $m分';
    return '$m分';
  }

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

  static String _pctOrNum(double v) => v.toStringAsFixed(2);

  static String _bytes(int n) {
    if (n < 0) return '暂无';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = n.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final s = v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return '$s ${units[i]}';
  }
}
