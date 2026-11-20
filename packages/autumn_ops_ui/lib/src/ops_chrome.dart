import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 概览/设置分区卡：浅底圆角 + 可选标题说明。
class OpsSectionCard extends StatelessWidget {
  const OpsSectionCard({
    super.key,
    this.title,
    this.body,
    required this.children,
  });

  final String? title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.isNotEmpty) ...[
              Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (body != null && body!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body!,
                  style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 列表计数胶囊 + 可选「加载更多」（IP/盾/跳共用；Stadium 真胶囊，禁止被拉成豆荚）。
class OpsCountChipBar extends StatelessWidget {
  const OpsCountChipBar({
    super.key,
    required this.loaded,
    required this.total,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.emptyLabel = '暂无记录',
  });

  final int loaded;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = total <= 0
        ? emptyLabel
        : loaded >= total
            ? '共 $total 条'
            : '已加载 $loaded / 共 $total';
    return Row(
      children: [
        // 固有宽胶囊：与文案同宽，半高圆角（StadiumBorder）
        Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Spacer(),
        if (hasMore && loaded > 0)
          TextButton(
            onPressed: loadingMore ? null : onLoadMore,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              loadingMore ? '加载中…' : '加载更多',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// 状态圆点 pill（已开启 / 已关闭等）。
class OpsStatusPill extends StatelessWidget {
  const OpsStatusPill({
    super.key,
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = active ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;
    final background = active
        ? scheme.tertiaryContainer.withValues(alpha: 0.55)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.9);
    final dot = active ? scheme.tertiary : scheme.outline;
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
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
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

/// 小标签（如「本机」），对齐 iOS `AutumnOpsMetaChipView`。
class OpsMetaChip extends StatelessWidget {
  const OpsMetaChip({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.primary),
      ),
    );
  }
}

/// 规则行卡片：左色条 + 主行 + 说明/日期 + 底栏动作。
///
/// IP 列表 SSOT（必须肉眼可见）：
/// ```
/// IP .................... [本机][胶囊][启停]   ← 右侧成组、顺序右贴边
/// 说明 .............................. [删除]   ← 删除与启停同列右对齐
/// 日期
/// ```
class OpsRuleRowChrome extends StatelessWidget {
  const OpsRuleRowChrome({
    super.key,
    required this.title,
    this.subtitle,
    this.detail,
    this.dateLine,
    required this.active,
    required this.statusLabel,
    this.actions = const [],
    this.primaryAction,
    this.trailingAction,
    this.titleMonospace = true,
    this.highlightedBorder = false,
    this.meta = const [],
  });

  final String title;

  /// 兼容盾/跳/证：单段副文（与 [detail]/[dateLine] 互斥优先用后两者）。
  final String? subtitle;

  /// 第二行说明（tag · description）。
  final String? detail;

  /// 第三行日期（独立换行）。
  final String? dateLine;
  final bool active;
  final String statusLabel;

  /// 底栏动作（盾/跳/证）。
  final List<Widget> actions;

  /// 第一行右侧成组末项：启停图标（在胶囊之后）。
  final Widget? primaryAction;

  /// 说明/日期行右侧：删除图标，与 [primaryAction] 右缘对齐。
  final Widget? trailingAction;
  final bool titleMonospace;

  /// 本机等：primary@0.45 描边。
  final bool highlightedBorder;

  /// 第一行右侧成组：在状态胶囊之前（如「本机」）。
  final List<Widget> meta;

  /// IP 行启停/删除：热区边长（与 iOS `kAutumnOpsActionSlot` 锁死）。
  static const double actionSlotWidth = 32;

  /// 图标字形边长（与 iOS SF Symbol 目视对齐：iOS 用同 pt + scaleSmall）。
  static const double actionIconSize = 20;

  TextStyle _bodyStyle(ColorScheme scheme) => TextStyle(
        fontSize: 13,
        height: 1.35,
        color: scheme.onSurfaceVariant,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSplitBody =
        (detail != null && detail!.isNotEmpty) || (dateLine != null && dateLine!.isNotEmpty);
    final legacySubtitle =
        !hasSplitBody && subtitle != null && subtitle!.isNotEmpty ? subtitle! : null;

    // 本机 → 胶囊 → 启停：mainAxisSize.min 整组贴右
    final statusCluster = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final m in meta) ...[
          m,
          const SizedBox(width: 6),
        ],
        OpsStatusPill(label: statusLabel, active: active),
        if (primaryAction != null) primaryAction!,
      ],
    );

    final bodyLines = <Widget>[
      if (detail != null && detail!.isNotEmpty) Text(detail!, style: _bodyStyle(scheme)),
      if (dateLine != null && dateLine!.isNotEmpty) ...[
        if (detail != null && detail!.isNotEmpty) const SizedBox(height: 4),
        Text(dateLine!, style: _bodyStyle(scheme)),
      ],
      if (legacySubtitle != null) ...[
        if (hasSplitBody) const SizedBox(height: 4),
        Text(legacySubtitle, style: _bodyStyle(scheme)),
      ],
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              actions[i],
            ],
          ],
        ),
      ],
    ];
    final showLower = bodyLines.isNotEmpty || trailingAction != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: highlightedBorder
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
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
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // IP 与右侧成组（本机/胶囊/启停）同一行垂直居中
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: SelectableText(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: titleMonospace ? 'monospace' : null,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 固定行高，避免 IconButton 默认 48 热区把启停顶离 IP 行
                            SizedBox(
                              height: actionSlotWidth,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: statusCluster,
                              ),
                            ),
                          ],
                        ),
                        if (showLower) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: bodyLines.isEmpty
                                    ? const SizedBox.shrink()
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: bodyLines,
                                      ),
                              ),
                              // 与第一行启停同宽槽位，右缘对齐（删除在启停正下方）
                              if (trailingAction != null)
                                SizedBox(
                                  width: actionSlotWidth,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: trailingAction!,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 双槽 fused：主输入 | 次输入 | 动作。
class OpsFusedDualFieldAction extends StatelessWidget {
  const OpsFusedDualFieldAction({
    super.key,
    required this.primaryController,
    required this.secondaryController,
    required this.primaryHint,
    required this.secondaryHint,
    required this.actionLabel,
    required this.onAction,
    this.enabled = true,
    this.primaryMonospace = true,
    this.secondaryKeyboardType,
    this.secondaryFormatters,
    this.height = 48,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
  });

  final TextEditingController primaryController;
  final TextEditingController secondaryController;
  final String primaryHint;
  final String secondaryHint;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool enabled;
  final bool primaryMonospace;
  final TextInputType? secondaryKeyboardType;
  final List<TextInputFormatter>? secondaryFormatters;
  final double height;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    InputDecoration bare(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontFamily: null,
            fontSize: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        );

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              flex: primaryFlex,
              child: TextField(
                controller: primaryController,
                enabled: enabled,
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontFamily: primaryMonospace ? 'monospace' : null,
                ),
                decoration: bare(primaryHint),
              ),
            ),
            Container(width: 1, height: double.infinity, color: scheme.outlineVariant),
            Expanded(
              flex: secondaryFlex,
              child: TextField(
                controller: secondaryController,
                enabled: enabled,
                keyboardType: secondaryKeyboardType,
                inputFormatters: secondaryFormatters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (onAction != null) onAction!();
                },
                style: const TextStyle(fontSize: 15, height: 1.2),
                decoration: bare(secondaryHint),
              ),
            ),
            Container(width: 1, height: double.infinity, color: scheme.outlineVariant),
            SizedBox(
              height: double.infinity,
              child: TextButton(
                onPressed: enabled ? onAction : null,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置行：左标题+副文，右 Switch。
class OpsSwitchRow extends StatelessWidget {
  const OpsSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// 微信小程序「回到列表」式图标：细圆环 + 中心实心方块。
class OpsSitesListIcon extends StatelessWidget {
  const OpsSitesListIcon({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _OpsSitesListIconPainter(c)),
    );
  }
}

class _OpsSitesListIconPainter extends CustomPainter {
  _OpsSitesListIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = (size.width * 0.09).clamp(1.2, 2.0);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - strokeW;
    canvas.drawCircle(center, outerR, stroke);
    // 中心实心方块（约外径 28%）
    final half = size.width * 0.14;
    canvas.drawRect(
      Rect.fromCenter(center: center, width: half * 2, height: half * 2),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _OpsSitesListIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
