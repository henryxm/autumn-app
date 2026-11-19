import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 盾牌：运行时三开关 + uri 规则列表。
class OpsShieldPanel extends StatefulWidget {
  const OpsShieldPanel({
    super.key,
    required this.client,
    required this.busy,
    required this.onBusyChanged,
    required this.onToast,
  });

  final Future<AutumnOpsClient?> Function() client;
  final bool busy;
  final ValueChanged<bool> onBusyChanged;
  final ValueChanged<String> onToast;

  @override
  State<OpsShieldPanel> createState() => _OpsShieldPanelState();
}

class _OpsShieldPanelState extends State<OpsShieldPanel> {
  final _uriCtrl = TextEditingController();
  final _autoCtrl = TextEditingController(text: '10000');
  final _scroll = ScrollController();

  OpsShieldStatus? _status;
  final List<OpsShieldRow> _rows = [];
  int _page = 1;
  int _count = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _uriCtrl.dispose();
    _autoCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _wrapBusy(Future<void> Function() action) async {
    if (widget.busy || _loading) return;
    widget.onBusyChanged(true);
    try {
      await action();
    } catch (e) {
      widget.onToast(OpsErrorMessage.of(e));
    } finally {
      widget.onBusyChanged(false);
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await widget.client();
      await c!.ensureSession();
      final status = await c.shieldStatus();
      final page = await c.shieldList(page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _status = status;
        _rows
          ..clear()
          ..addAll(page.list);
        _page = page.page;
        _count = page.count;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = OpsErrorMessage.display(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final c = await widget.client();
      final page = await c!.shieldList(page: _page + 1, limit: 50);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.list);
        _page = page.page;
        _count = page.count;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      widget.onToast(OpsErrorMessage.of(e));
    }
  }

  Future<void> _setStatus({bool? attack, bool? printEnabled, bool? enable}) async {
    await _wrapBusy(() async {
      final c = await widget.client();
      OpsShieldStatus next = _status ??
          const OpsShieldStatus(attack: false, printEnabled: false, enable: false);
      if (attack != null) next = await c!.shieldSetAttack(attack);
      if (printEnabled != null) next = await c!.shieldSetPrint(printEnabled);
      if (enable != null) next = await c!.shieldSetEnable(enable);
      if (!mounted) return;
      setState(() => _status = next);
    });
  }

  Future<void> _addRule() async {
    final uri = _uriCtrl.text.trim();
    if (uri.isEmpty) {
      widget.onToast('请填写资源路径，例如 / 或 /api');
      return;
    }
    final auto = int.tryParse(_autoCtrl.text.trim()) ?? 0;
    if (auto < 1000) {
      widget.onToast('自动阈值须不小于 1000');
      return;
    }
    await _wrapBusy(() async {
      final c = await widget.client();
      await c!.shieldSave(uri: uri, enable: true, auto: auto);
      _uriCtrl.clear();
      widget.onToast('已添加盾牌规则：$uri');
      await _reload();
    });
  }

  Future<void> _toggleRow(OpsShieldRow row) async {
    await _wrapBusy(() async {
      final c = await widget.client();
      await c!.shieldUpdate(id: row.id, enable: !row.enable);
      widget.onToast(row.enable ? '已关闭：${row.uri}' : '已开启：${row.uri}');
      await _reload();
    });
  }

  Future<void> _deleteRow(OpsShieldRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除盾牌规则'),
        content: Text('确定删除 ${row.uri}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await _wrapBusy(() async {
      final c = await widget.client();
      await c!.shieldDelete([row.id]);
      widget.onToast('已删除：${row.uri}');
      await _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            '攻击防御（盾牌）',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '配置需防护的资源路径；总开关写库生效。攻击模式与打印为运行时开关。',
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (status != null) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('总开关'),
              subtitle: const Text('写库启用/关闭默认盾牌规则集'),
              value: status.enable,
              onChanged: widget.busy ? null : (v) => _setStatus(enable: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('攻击模式'),
              subtitle: const Text('开启后对未放行 IP 拦截匹配资源'),
              value: status.attack,
              onChanged: widget.busy ? null : (v) => _setStatus(attack: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('打印日志'),
              subtitle: const Text('拦截/放行时输出防护日志'),
              value: status.printEnabled,
              onChanged: widget.busy ? null : (v) => _setStatus(printEnabled: v),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _uriCtrl,
                  enabled: !widget.busy,
                  decoration: const InputDecoration(
                    labelText: '资源 uri',
                    hintText: '/',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _autoCtrl,
                  enabled: !widget.busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'auto',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: widget.busy ? null : _addRule,
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _count <= 0 ? '暂无规则' : '共 $_count 条',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            )
          else
            ..._rows.map((row) {
              return Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  title: Text(row.uri, style: const TextStyle(fontFamily: 'monospace')),
                  subtitle: Text('auto ${row.auto} · ${row.enable ? '已开启' : '已关闭'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: widget.busy ? null : () => _toggleRow(row),
                        child: Text(row.enable ? '关闭' : '开启'),
                      ),
                      IconButton(
                        onPressed: widget.busy ? null : () => _deleteRow(row),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除',
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}
