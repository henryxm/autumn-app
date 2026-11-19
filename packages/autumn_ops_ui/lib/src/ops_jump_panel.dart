import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';

/// 防御跳转：host+uri → url 规则列表。
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
            return AlertDialog(
              title: Text(existing == null ? '添加跳转' : '编辑跳转'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: hostCtrl,
                      decoration: const InputDecoration(
                        labelText: '域名 host',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: uriCtrl,
                      decoration: const InputDecoration(
                        labelText: '资源 uri',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(
                        labelText: '跳转 url',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开启'),
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
      widget.onToast('host、uri、url 均不能为空');
      return;
    }
    await _wrapBusy(() async {
      final c = await widget.client();
      if (existing == null) {
        await c!.jumpSave(host: host, uri: uri, url: url, enable: enable);
        widget.onToast('已添加跳转：$host$uri');
      } else {
        await c!.jumpUpdate(
          id: existing.id,
          host: host,
          uri: uri,
          url: url,
          enable: enable,
        );
        widget.onToast('已更新跳转：$host$uri');
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
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
            children: [
              Expanded(
                child: Text(
                  '防御跳转',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: widget.busy ? null : () => _edit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '按域名 + 资源匹配后跳转到目标 URL。与盾牌分表，互不影响。',
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
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
                  title: Text(
                    '${row.host}${row.uri}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                  subtitle: Text(
                    '→ ${row.url}\n${row.enable ? '已开启' : '已关闭'}',
                    style: const TextStyle(height: 1.35),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: widget.busy ? null : () => _edit(existing: row),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: '编辑',
                      ),
                      TextButton(
                        onPressed: widget.busy ? null : () => _toggle(row),
                        child: Text(row.enable ? '关闭' : '开启'),
                      ),
                      IconButton(
                        onPressed: widget.busy ? null : () => _delete(row),
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
