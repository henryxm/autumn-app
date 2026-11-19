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

/// 列表计数 pill + 可选「加载更多」。
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
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

/// 规则行卡片：左色条 + 主/副文 + 状态 pill + 底栏动作。
class OpsRuleRowChrome extends StatelessWidget {
  const OpsRuleRowChrome({
    super.key,
    required this.title,
    this.subtitle,
    required this.active,
    required this.statusLabel,
    required this.actions,
    this.titleMonospace = true,
  });

  final String title;
  final String? subtitle;
  final bool active;
  final String statusLabel;
  final List<Widget> actions;
  final bool titleMonospace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
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
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(width: 6),
                          OpsStatusPill(label: statusLabel, active: active),
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
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
                    ],
                  ),
                ),
              ),
            ],
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
