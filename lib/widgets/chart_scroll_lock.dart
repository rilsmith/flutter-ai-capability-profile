import 'package:flutter/material.dart';

/// Signals the page [SingleChildScrollView] to disable scrolling while a radar
/// chart dot is being dragged.
class ChartScrollLock extends InheritedWidget {
  const ChartScrollLock({
    super.key,
    required this.dragging,
    required super.child,
  });

  final ValueNotifier<bool> dragging;

  static ChartScrollLock? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ChartScrollLock>();
  }

  void setLocked(bool locked) {
    if (dragging.value != locked) {
      dragging.value = locked;
    }
  }

  @override
  bool updateShouldNotify(ChartScrollLock oldWidget) {
    return dragging != oldWidget.dragging;
  }
}
