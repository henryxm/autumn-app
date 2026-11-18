import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';

/// IP 列表状态字段语义。
enum OpsIpStatusMode {
  /// 白名单类：`forbidden` 0 启用 / 1 禁用。
  forbidden,

  /// 黑名单类：`available` 1 生效 / 0 停用。
  available,
}

typedef OpsIpPageLoader = Future<OpsIpPage> Function({required int page, required int limit});
typedef OpsIpToggle = Future<void> Function(String ip, {required bool enable});

/// 统一的运维 IP 列表：下拉刷新、触底加载、添加/认领、禁用/启用、删除。
class OpsIpListPanel extends StatefulWidget {
  const OpsIpListPanel({
    super.key,
    required this.title,
    required this.description,
    required this.statusMode,
    required this.loadPage,
    required this.onAdd,
    required this.onRemove,
    required this.onToggle,
    this.currentIp = '',
    this.resolveClearToken,
    this.allowClaimCurrent = true,
    this.ipInputHint = '请输入 IP 地址',
    this.requireClearTokenForCurrent = true,
    this.busy = false,
    this.onBusyChanged,
    this.onToast,
    this.header,
    this.footer,
  });

  final String title;
  final String description;
  final OpsIpStatusMode statusMode;
  final OpsIpPageLoader loadPage;
  final Future<String> Function({String? ip, bool claimCurrent}) onAdd;
  final Future<void> Function(String ip, {String? clearToken}) onRemove;

  /// [enable]=true 表示启用（白名单取消禁用 / 黑名单设为生效）。
  final OpsIpToggle onToggle;
  final String currentIp;

  /// 删除当前访问 IP 等危险操作时解析清除确认令牌；返回 `null` 表示用户取消。
  final Future<String?> Function({required String reason})? resolveClearToken;
  final bool allowClaimCurrent;
  final String ipInputHint;
  final bool requireClearTokenForCurrent;
  final bool busy;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<String>? onToast;
  final Widget? header;
  final Widget? footer;

  @override
  State<OpsIpListPanel> createState() => _OpsIpListPanelState();
}

class _OpsIpListPanelState extends State<OpsIpListPanel> {
  final _ipCtrl = TextEditingController();
  final _scroll = ScrollController();

  final List<OpsIpRow> _rows = [];
  int _page = 0;
  int _count = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  static const _limit = 20;

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
    _ipCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) => widget.onToast?.call(msg);

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _wrapBusy(Future<void> Function() action) async {
    if (widget.busy || _loading) return;
    widget.onBusyChanged?.call(true);
    try {
      await action();
    } catch (e) {
      _toast(OpsErrorMessage.of(e));
    } finally {
      widget.onBusyChanged?.call(false);
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loadPage(page: 1, limit: _limit);
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
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final page = await widget.loadPage(page: next, limit: _limit);
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
      _toast(OpsErrorMessage.of(e));
    }
  }

  String _statusLabel(OpsIpRow row) {
    switch (widget.statusMode) {
      case OpsIpStatusMode.forbidden:
        return row.isForbidden ? '已禁用' : '启用中';
      case OpsIpStatusMode.available:
        return row.isAvailable ? '生效中' : '已停用';
    }
  }

  bool _isActive(OpsIpRow row) {
    switch (widget.statusMode) {
      case OpsIpStatusMode.forbidden:
        return !row.isForbidden;
      case OpsIpStatusMode.available:
        return row.isAvailable;
    }
  }

  Future<void> _toggle(OpsIpRow row) async {
    final active = _isActive(row);
    final nextEnable = !active;
    final title = nextEnable ? '启用' : (widget.statusMode == OpsIpStatusMode.available ? '停用' : '禁用');
    if (!await _confirm('$title IP', '确定${title} ${row.ip}？')) return;
    await _wrapBusy(() async {
      await widget.onToggle(row.ip, enable: nextEnable);
      _toast('已$title：${row.ip}');
      await _reload();
    });
  }

  Future<void> _remove(OpsIpRow row) async {
    final needToken =
        widget.requireClearTokenForCurrent && row.ip == widget.currentIp && widget.currentIp.isNotEmpty;
    if (!await _confirm(
      '删除 IP',
      needToken ? '删除的是当前访问 IP，须提供清除确认令牌。确定删除 ${row.ip}？' : '确定删除 ${row.ip}？',
    )) {
      return;
    }
    String? token;
    if (needToken) {
      token = await widget.resolveClearToken?.call(reason: '删除当前访问 IP：${row.ip}');
      if (token == null || token.isEmpty) {
        _toast('已取消：需要清除确认令牌');
        return;
      }
    }
    await _wrapBusy(() async {
      await widget.onRemove(row.ip, clearToken: token);
      _toast('已删除：${row.ip}');
      await _reload();
    });
  }

  bool get _currentIpAlreadyListed {
    final ip = widget.currentIp.trim();
    if (ip.isEmpty) return false;
    return _rows.any((r) => r.ip == ip);
  }

  Future<void> _submitManualIp() async {
    final ip = _ipCtrl.text.trim();
    final check = OpsValidators.wallIp(ip);
    if (!check.ok) {
      _toast(check.error!);
      return;
    }
    await _wrapBusy(() async {
      final saved = await widget.onAdd(ip: ip);
      _ipCtrl.clear();
      _toast('已添加：$saved');
      await _reload();
    });
  }

  Widget _buildIpInputBar(ColorScheme scheme) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipCtrl,
                enabled: !widget.busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!widget.busy) _submitManualIp();
                },
                style: const TextStyle(fontSize: 15, height: 1.2),
                decoration: InputDecoration(
                  hintText: widget.ipInputHint,
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                ),
                keyboardType: TextInputType.text,
              ),
            ),
            Container(width: 1, height: double.infinity, color: scheme.outlineVariant),
            SizedBox(
              height: double.infinity,
              child: TextButton(
                onPressed: widget.busy ? null : _submitManualIp,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Text('添加', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showClaimCurrent = widget.allowClaimCurrent && !_currentIpAlreadyListed;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 16),
          ],
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            widget.description,
            style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _buildIpInputBar(scheme),
          if (showClaimCurrent) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: widget.busy
                    ? null
                    : () => _wrapBusy(() async {
                          final ip = await widget.onAdd(claimCurrent: true);
                          _toast('已加入：$ip');
                          await _reload();
                        }),
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('加入当前 IP'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _count > 0 ? '共 $_count 条' : '暂无记录',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (_loading && _rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
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
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('暂无 IP，可先「加入当前 IP」', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            )
          else
            ..._rows.map(_buildRow),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_rows.isNotEmpty && !_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('没有更多了', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            ),
          if (widget.footer != null) ...[
            const SizedBox(height: 16),
            widget.footer!,
          ],
        ],
      ),
    );
  }

  Widget _buildRow(OpsIpRow row) {
    final scheme = Theme.of(context).colorScheme;
    final active = _isActive(row);
    final subtitle = [
      if ((row.tag ?? '').trim().isNotEmpty) row.tag!.trim(),
      if ((row.description ?? '').trim().isNotEmpty) row.description!.trim(),
    ].join(' · ');
    final isCurrent = widget.currentIp.isNotEmpty && row.ip == widget.currentIp;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(row.ip, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            ),
            if (isCurrent)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: const Text('本机'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelStyle: TextStyle(fontSize: 11, color: scheme.primary),
                  side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
                  backgroundColor: scheme.primaryContainer.withValues(alpha: 0.35),
                ),
              ),
            Chip(
              label: Text(_statusLabel(row)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(
                fontSize: 11,
                color: active ? scheme.onSecondaryContainer : scheme.onErrorContainer,
              ),
              backgroundColor: active
                  ? scheme.secondaryContainer.withValues(alpha: 0.7)
                  : scheme.errorContainer.withValues(alpha: 0.55),
              side: BorderSide.none,
            ),
          ],
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
        trailing: PopupMenuButton<String>(
          enabled: !widget.busy,
          onSelected: (v) {
            if (v == 'toggle') {
              _toggle(row);
            } else if (v == 'delete') {
              _remove(row);
            }
          },
          itemBuilder: (ctx) {
            final toggleLabel = active
                ? (widget.statusMode == OpsIpStatusMode.available ? '停用' : '禁用')
                : '启用';
            return [
              PopupMenuItem(value: 'toggle', child: Text(toggleLabel)),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除', style: TextStyle(color: Colors.redAccent)),
              ),
            ];
          },
        ),
      ),
    );
  }
}
