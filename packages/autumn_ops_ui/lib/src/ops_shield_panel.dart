import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ops_chrome.dart';

/// 盾牌：设置卡三开关 + fused 添加条 + 规则行。
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
      widget.onToast('已添加：$uri');
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
        title: const Text('删除规则'),
        content: Text('确定删除 ${row.uri}？'),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, false);
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(ctx, true);
            },
            child: const Text('删除'),
          ),
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
            '攻击防御',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '配置需防护的资源路径；总开关写库生效，攻击模式与打印为运行时开关。',
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (status != null)
            OpsSectionCard(
              title: '运行开关',
              body: '总开关写入数据库；攻击模式与打印仅影响当前进程内存。',
              children: [
                OpsSwitchRow(
                  title: '总开关',
                  subtitle: '启用或关闭默认盾牌规则集',
                  value: status.enable,
                  onChanged: widget.busy ? null : (v) => _setStatus(enable: v),
                ),
                OpsSwitchRow(
                  title: '攻击模式',
                  subtitle: '对未放行 IP 拦截匹配资源',
                  value: status.attack,
                  onChanged: widget.busy ? null : (v) => _setStatus(attack: v),
                ),
                OpsSwitchRow(
                  title: '打印日志',
                  subtitle: '拦截与放行时输出防护日志',
                  value: status.printEnabled,
                  onChanged: widget.busy ? null : (v) => _setStatus(printEnabled: v),
                ),
              ],
            ),
          const SizedBox(height: 12),
          OpsFusedDualFieldAction(
            primaryController: _uriCtrl,
            secondaryController: _autoCtrl,
            primaryHint: '资源路径，如 /',
            secondaryHint: '自动阈值',
            actionLabel: '添加',
            enabled: !widget.busy,
            secondaryKeyboardType: TextInputType.number,
            secondaryFormatters: [FilteringTextInputFormatter.digitsOnly],
            onAction: widget.busy ? null : _addRule,
          ),
          const SizedBox(height: 12),
          OpsCountChipBar(
            loaded: _rows.length,
            total: _count,
            hasMore: _hasMore && !_loading,
            loadingMore: _loadingMore,
            onLoadMore: widget.busy ? null : _loadMore,
            emptyLabel: '暂无规则',
          ),
          const SizedBox(height: 8),
          if (_loading && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text('加载失败：$_error', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _reload, child: const Text('重试')),
                ],
              ),
            )
          else if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  '暂无规则，在上方填写路径后添加',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._rows.map((row) {
              return OpsRuleRowChrome(
                title: row.uri,
                subtitle: '自动阈值 · ${row.auto}',
                active: row.enable,
                statusLabel: row.enable ? '已开启' : '已关闭',
                actions: [
                  TextButton(
                    onPressed: widget.busy ? null : () => _toggleRow(row),
                    child: Text(row.enable ? '关闭' : '开启'),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : () => _deleteRow(row),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    child: const Text('删除'),
                  ),
                ],
              );
            }),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_rows.isNotEmpty && !_hasMore)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Center(
                child: Text(
                  '已全部加载',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
