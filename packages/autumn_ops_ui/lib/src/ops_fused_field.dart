import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 左侧输入 + 右侧动作，运维 App 统一视觉语言。
class OpsFusedFieldAction extends StatelessWidget {
  const OpsFusedFieldAction({
    super.key,
    required this.controller,
    required this.hintText,
    required this.actionLabel,
    required this.onAction,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.done,
    this.onChanged,
    this.leading,
    this.trailing,
    this.inputFormatters,
    this.height = 52,
    this.monospace = false,
  });

  final TextEditingController controller;
  final String hintText;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final Widget? leading;
  final Widget? trailing;
  final List<TextInputFormatter>? inputFormatters;
  final double height;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            if (leading != null) leading!,
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                enabled: enabled,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                inputFormatters: inputFormatters,
                onChanged: onChanged,
                onSubmitted: (_) {
                  if (onAction != null) onAction!();
                },
                style: TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontFamily: monospace ? 'monospace' : null,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontFamily: null,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  suffixIcon: trailing,
                ),
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

/// 整行可点的融合动作条（如「选择文件」），右侧为动作文案。
class OpsFusedActionBar extends StatelessWidget {
  const OpsFusedActionBar({
    super.key,
    required this.label,
    required this.actionLabel,
    required this.onAction,
    this.enabled = true,
    this.icon,
    this.height = 52,
  });

  final String label;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool enabled;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: InkWell(
          onTap: enabled ? onAction : null,
          child: Row(
            children: [
              if (icon != null) ...[
                const SizedBox(width: 12),
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: label.startsWith('已选')
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: double.infinity, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  actionLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: enabled ? scheme.primary : scheme.onSurface.withValues(alpha: 0.38),
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

/// 添加页分区卡片。
class OpsAddSection extends StatelessWidget {
  const OpsAddSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
