import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 点击当前焦点输入框以外的区域时收起键盘。
class OpsKeyboardDismiss extends StatelessWidget {
  const OpsKeyboardDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _unfocusIfOutside,
      child: child,
    );
  }

  static void _unfocusIfOutside(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || focus.context == null) return;

    final box = _focusBox(focus.context!);
    if (box == null || !box.hasSize) {
      // 无尺寸焦点节点：直接收起，避免键盘残留
      if (focus.context!.widget is EditableText ||
          focus.context!.findAncestorWidgetOfExactType<EditableText>() != null ||
          focus.context!.findAncestorWidgetOfExactType<TextField>() != null ||
          focus.context!.findAncestorWidgetOfExactType<TextFormField>() != null) {
        focus.unfocus();
      }
      return;
    }

    final local = box.globalToLocal(event.position);
    if (!box.paintBounds.contains(local)) {
      focus.unfocus();
    }
  }

  static RenderBox? _focusBox(BuildContext context) {
    final editable = context.findAncestorRenderObjectOfType<RenderEditable>();
    if (editable != null) return editable;
    final obj = context.findRenderObject();
    return obj is RenderBox ? obj : null;
  }
}
