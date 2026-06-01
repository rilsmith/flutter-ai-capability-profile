import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/utils/compute.dart';
import 'package:ai_capability_dashboard/widgets/chart_scroll_lock.dart';
import 'package:ai_capability_dashboard/widgets/interactive_radar_chart.dart';

Widget _withScrollLock({required Widget child, ValueNotifier<bool>? lock}) {
  final notifier = lock ?? ValueNotifier(false);
  return ChartScrollLock(
    dragging: notifier,
    child: child,
  );
}

void main() {
  testWidgets('dot drag commits score once on release', (tester) async {
    var updateCount = 0;
    double? lastScore;

    await tester.pumpWidget(
      MaterialApp(
        home: _withScrollLock(
          child: SizedBox(
            width: 400,
            height: 400,
            child: InteractiveRadarChart(
            dimensions: defaultDashboardData.dimensions,
            maxScore: defaultDashboardData.maxScore,
            onDragPreview: (_, __) {},
            onDragCancel: () {},
            onUpdateScore: (_, score) {
              updateCount++;
              lastScore = score;
            },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final dotGlobal = _firstDotGlobal(tester);
    final gesture = await tester.startGesture(dotGlobal);
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(updateCount, 0);

    await gesture.up();
    await tester.pump();

    expect(updateCount, 1);
    expect(lastScore, isNotNull);
  });

  testWidgets('dot drag holds parent scroll position', (tester) async {
    final scrollController = ScrollController();
    final chartDragging = ValueNotifier(false);

    await tester.pumpWidget(
      MaterialApp(
        home: _withScrollLock(
          lock: chartDragging,
          child: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: chartDragging,
              builder: (context, locked, child) {
                return SingleChildScrollView(
                  controller: scrollController,
                  physics: locked
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: child,
                );
              },
              child: Column(
              children: [
                const SizedBox(height: 1200),
                SizedBox(
                  width: 400,
                  height: 400,
                  child: InteractiveRadarChart(
                    dimensions: defaultDashboardData.dimensions,
                    maxScore: defaultDashboardData.maxScore,
                    onDragPreview: (_, __) {},
                    onDragCancel: () {},
                    onUpdateScore: (_, __) {},
                  ),
                ),
                const SizedBox(height: 1200),
              ],
            ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    scrollController.jumpTo(200);
    await tester.pump();

    final dotGlobal = _firstDotGlobal(tester);

    final gesture = await tester.startGesture(dotGlobal);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(scrollController.offset, 200);
  });
}

Offset _firstDotGlobal(WidgetTester tester) {
  const cx = 550.0;
  const cy = 550.0;
  const maxRadius = 240.0;
  final firstScore = defaultDashboardData.dimensions.first.score;
  final r = (firstScore / defaultDashboardData.maxScore) * maxRadius;
  final polar = polarToXY(cx, cy, r, 0);

  final viewBoxBox = tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(InteractiveRadarChart),
      matching: find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 1100,
      ),
    ),
  );
  return viewBoxBox.localToGlobal(Offset(polar.x, polar.y));
}
