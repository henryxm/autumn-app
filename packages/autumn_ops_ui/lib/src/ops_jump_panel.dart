import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';

import 'ops_chrome.dart';

/// 防御跳转：次要添加入口 + 规则行卡片。
class OpsJumpPanel extends StatefulWidget {
  const OpsJumpPanel({
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
  State<OpsJumpPanel> createState() => _OpsJumpPanelState();
}

class _OpsJumpPanelState extends State<OpsJumpPanel> {
  final _scroll = ScrollController();
  final List<OpsJumpRow> _rows = [];
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
      final page = await c.jumpList(page: 1, limit: 50);
      if (!mounted) return;
      setState(() {
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
      final page = await c!.jumpList(page: _page + 1, limit: 50);
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

  Future<void> _edit({OpsJumpRow? existing}) async {
    final hostCtrl = TextEditingController(text: existing?.host ?? '');
    final uriCtrl = TextEditingController(text: existing?.uri ?? '/');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    var enable = existing?.enable ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final scheme = Theme.of(ctx).colorScheme;
            final fieldBorder = OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: scheme.outlineVariant),
            );
            return AlertDialog(
              title: Text(existing == null ? '添加跳转' : '编辑跳转'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: hostCtrl,
                      decoration: InputDecoration(
                        labelText: '域名',
                        hintText: '例如 www.example.com',
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: BorderSide(color: scheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: uriCtrl,
                      decoration: InputDecoration(
                        labelText: '资源路径',
                        hintText: '/',
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: BorderSide(color: scheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: '跳转地址',
                        hintText: 'https://…',
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: BorderSide(color: scheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    OpsSwitchRow(
                      title: '开启',
                      subtitle: '关闭后保留规则但不跳转',
                      value: enable,
                      onChanged: (v) => setLocal(() => enable = v),
                    ),
                  ],
                ),
              ),
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
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
    final host = hostCtrl.text.trim();
    final uri = uriCtrl.text.trim();
    final url = urlCtrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      hostCtrl.dispose();
      uriCtrl.dispose();
      urlCtrl.dispose();
    });
    if (ok != true) return;
    if (host.isEmpty || uri.isEmpty || url.isEmpty) {
      widget.onToast('域名、资源路径、跳转地址均不能为空');
      return;
    }
    await _wrapBusy(() async {
      final c = await widget.client();
      if (existing == null) {
        await c!.jumpSave(host: host, uri: uri, url: url, enable: enable);
        widget.onToast('已添加：$host$uri');
      } else {
        await c!.jumpUpdate(
          id: existing.id,
          host: host,
          uri: uri,
          url: url,
          enable: enable,
        );
        widget.onToast('已更新：$host$uri');
      }
      await _reload();
    });
  }

  Future<void> _toggle(OpsJumpRow row) async {
    await _wrapBusy(() async {
      final c = await widget.client();
      await c!.jumpUpdate(id: row.id, enable: !row.enable);
      widget.onToast(row.enable ? '已关闭：${row.host}${row.uri}' : '已开启：${row.host}${row.uri}');
      await _reload();
    });
  }

  Future<void> _delete(OpsJumpRow row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除跳转'),
        content: Text('确定删除 ${row.host}${row.uri}？'),
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
      await c!.jumpDelete([row.id]);
      widget.onToast('已删除：${row.host}${row.uri}');
      await _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '防御跳转',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '按域名与资源匹配后跳转到目标地址，与盾牌分表互不影响。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: widget.busy ? null : () => _edit(),
                child: const Text('添加'),
              ),
            ],
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
                  '暂无跳转规则，点右上角添加',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._rows.map((row) {
              return OpsRuleRowChrome(
                title: '${row.host}${row.uri}',
                subtitle: '→ ${row.url}',
                active: row.enable,
                statusLabel: row.enable ? '已开启' : '已关闭',
                actions: [
                  TextButton(
                    onPressed: widget.busy ? null : () => _edit(existing: row),
                    child: const Text('编辑'),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : () => _toggle(row),
                    child: Text(row.enable ? '关闭' : '开启'),
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : () => _delete(row),
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
