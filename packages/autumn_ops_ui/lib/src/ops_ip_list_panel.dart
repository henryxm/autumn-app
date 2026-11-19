import 'package:autumn_ops/autumn_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// IP 列表状态字段语义。
enum OpsIpStatusMode {
  /// 白名单类：`forbidden` 0 启用 / 1 禁用。
  forbidden,

  /// 黑名单类：`available` 0 生效 / 1 停用（与 wall `getIps(0)` 一致）。
  available,
}

typedef OpsIpPageLoader = Future<OpsIpPage> Function({required int page, required int limit});
typedef OpsIpToggle = Future<void> Function(String ip, {required bool enable});

/// 统一的运维 IP 列表：下拉刷新、触底分页、添加/认领、启用停用、删除。
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
    this.claimCurrentHidden = false,
    this.ipInputHint = '请输入 IP 地址',
    this.requireClearTokenForCurrent = true,
    this.busy = false,
    this.onBusyChanged,
    this.onToast,
    this.onMembershipMayChange,
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

  /// 为 true 时隐藏「加入当前 IP」（例如已在管理 IP 或服务端判定已在白名单）。
  final bool claimCurrentHidden;
  final String ipInputHint;
  final bool requireClearTokenForCurrent;
  final bool busy;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<String>? onToast;

  /// 认领/添加/删除可能改变当前 IP 成员资格时回调（父页应刷新 `currentIp`）。
  final VoidCallback? onMembershipMayChange;
  final Widget? header;
  final Widget? footer;

  @override
  State<OpsIpListPanel> createState() => _OpsIpListPanelState();
}

class _OpsIpListPanelState extends State<OpsIpListPanel> {
  final _ipCtrl = TextEditingController();
  final _scroll = ScrollController();

  final List<OpsIpRow> _rows = [];
  final Set<String> _seenIps = {};
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
    // 距底部约一屏时预取，减少「滑到底才转圈」的顿挫
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  void _replaceRows(List<OpsIpRow> list, {required int page, required int count, required bool hasMore}) {
    _seenIps
      ..clear()
      ..addAll(list.map((e) => e.ip));
    _rows
      ..clear()
      ..addAll(list);
    _page = page;
    _count = count;
    _hasMore = hasMore && list.isNotEmpty;
  }

  void _appendRows(List<OpsIpRow> list, {required int page, required int count, required bool hasMore}) {
    var added = 0;
    for (final row in list) {
      if (_seenIps.add(row.ip)) {
        _rows.add(row);
        added++;
      }
    }
    _page = page;
    _count = count;
    // 本页无新数据或服务端声明没有更多 → 结束
    _hasMore = hasMore && added > 0;
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
        _replaceRows(
          page.list,
          page: page.page,
          count: page.count,
          hasMore: page.hasMore,
        );
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
      final next = _page + 1;
      final page = await widget.loadPage(page: next, limit: _limit);
      if (!mounted) return;
      setState(() {
        _appendRows(
          page.list,
          page: page.page,
          count: page.count,
          hasMore: page.hasMore,
        );
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
        return row.isBlackActive ? '生效中' : '已停用';
    }
  }

  bool _isActive(OpsIpRow row) {
    switch (widget.statusMode) {
      case OpsIpStatusMode.forbidden:
        return !row.isForbidden;
      case OpsIpStatusMode.available:
        return row.isBlackActive;
    }
  }

  String _toggleActionLabel(OpsIpRow row) {
    final active = _isActive(row);
    if (!active) return '启用';
    return widget.statusMode == OpsIpStatusMode.available ? '停用' : '禁用';
  }

  Future<void> _toggle(OpsIpRow row) async {
    final nextEnable = !_isActive(row);
    final title = _toggleActionLabel(row);
    if (!await _confirm('$title IP', '确定$title ${row.ip}？')) return;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _toast('已取消：需要清除确认令牌');
        });
        return;
      }
    }
    await _wrapBusy(() async {
      await widget.onRemove(row.ip, clearToken: token);
      _toast('已删除：${row.ip}');
      await _reload();
      widget.onMembershipMayChange?.call();
    });
  }

  bool get _currentIpAlreadyListed {
    final ip = widget.currentIp.trim();
    if (ip.isEmpty) return false;
    return _seenIps.contains(ip);
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
      widget.onMembershipMayChange?.call();
    });
  }

  String _formatTime(int? ms) {
    if (ms == null || ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
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
        height: 48,
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
                style: const TextStyle(fontSize: 15, height: 1.2, fontFamily: 'monospace'),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                decoration: InputDecoration(
                  hintText: widget.ipInputHint,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontFamily: null,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildCountBar(ColorScheme scheme) {
    final loaded = _rows.length;
    final total = _count;
    final text = total <= 0
        ? '暂无记录'
        : loaded >= total
            ? '共 $total 条'
            : '已加载 $loaded / 共 $total';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
          ),
        ),
        const Spacer(),
        if (_hasMore && !_loading && _rows.isNotEmpty)
          TextButton(
            onPressed: widget.busy || _loadingMore ? null : _loadMore,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              _loadingMore ? '加载中…' : '加载更多',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showClaimCurrent = widget.allowClaimCurrent &&
        widget.currentIp.isNotEmpty &&
        !widget.claimCurrentHidden &&
        !_currentIpAlreadyListed;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 12),
          ],
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.description,
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _buildIpInputBar(scheme),
          if (showClaimCurrent) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: widget.busy
                    ? null
                    : () => _wrapBusy(() async {
                          final ip = await widget.onAdd(claimCurrent: true);
                          _toast('已加入：$ip');
                          await _reload();
                          widget.onMembershipMayChange?.call();
                        }),
                icon: const Icon(Icons.my_location, size: 18),
                label: Text('加入当前 IP（${widget.currentIp}）'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildCountBar(scheme),
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
                  widget.allowClaimCurrent ? '暂无 IP，可添加或「加入当前 IP」' : '暂无 IP，请在上方输入后添加',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._rows.map(_buildRow),
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
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
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
    final isCurrent = widget.currentIp.isNotEmpty && row.ip == widget.currentIp;
    final time = _formatTime(row.createTimeMs);
    final meta = <String>[
      if ((row.tag ?? '').trim().isNotEmpty) row.tag!.trim(),
      if ((row.description ?? '').trim().isNotEmpty) row.description!.trim(),
      if (time.isNotEmpty) time,
    ];

    final statusColor = active ? scheme.tertiary : scheme.outline;
    final statusBg = active
        ? scheme.tertiaryContainer.withValues(alpha: 0.55)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCurrent
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: active ? scheme.tertiary : scheme.outlineVariant,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SelectableText(
                              row.ip,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: 'monospace',
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _StatusPill(
                            label: _statusLabel(row),
                            foreground: active ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                            background: statusBg,
                            dotColor: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isCurrent)
                            _MetaChip(
                              label: '本机访问',
                              color: scheme.primary,
                              background: scheme.primaryContainer.withValues(alpha: 0.4),
                            ),
                          ...meta.map(
                            (m) => Text(
                              m,
                              style: TextStyle(fontSize: 12, height: 1.2, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: _toggleActionLabel(row),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.busy ? null : () => _toggle(row),
                    icon: Icon(
                      active ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: '删除',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.busy ? null : () => _remove(row),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 22,
                      color: scheme.error.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.dotColor,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
