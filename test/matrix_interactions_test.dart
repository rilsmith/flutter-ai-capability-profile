import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/models/dimension.dart';
import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/utils/application.dart';
import 'package:ai_capability_dashboard/widgets/capability_application_matrix.dart';
import 'package:ai_capability_dashboard/widgets/sdlc_tab.dart';

Finder _findDataCellInkWells() {
  return find.descendant(
    of: find.byType(CapabilityApplicationMatrix),
    matching: find.byWidgetPredicate(
      (widget) => widget is InkWell && widget.child is SizedBox,
    ),
  );
}

void main() {
  group('CapabilityApplicationMatrix', () {
    testWidgets('tapping an empty cell toggles the link on and updates reach',
        (tester) async {
      final dashboardNotifier = DashboardNotifier.forTesting();
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CapabilityApplicationMatrix(
                dimensions: dashboardNotifier.data.dimensions,
                domains: dashboardNotifier.data.applicationDomains,
                maxScore: dashboardNotifier.data.maxScore,
                onToggleCapabilityLink: dashboardNotifier.toggleDomainCapability,
                submitEnabled: false,
                onSubmit: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstDimension = dashboardNotifier.data.dimensions.first;
      final firstDomain = dashboardNotifier.data.applicationDomains.first;
      expect(firstDomain.isNotApplicable, isFalse);
      expect(firstDomain.capabilityIds, isNot(contains(firstDimension.id)));

      final initialReach = linkedDomainCount(
        firstDimension.id,
        dashboardNotifier.data.applicationDomains,
      );
      expect(initialReach, 0);

      final cellInkWells = _findDataCellInkWells();
      expect(cellInkWells, findsWidgets);

      await tester.tap(cellInkWells.first);
      await tester.pumpAndSettle();

      final updatedDomain = dashboardNotifier.data.applicationDomains.first;
      expect(updatedDomain.capabilityIds, contains(firstDimension.id));
      expect(
        linkedDomainCount(
          firstDimension.id,
          dashboardNotifier.data.applicationDomains,
        ),
        1,
      );
    });

    testWidgets('tapping a linked cell toggles the link off',
        (tester) async {
      final dashboardNotifier = DashboardNotifier.forTesting();
      final firstDimension = dashboardNotifier.data.dimensions.first;

      // Pre-link the first domain to the first dimension.
      dashboardNotifier.toggleDomainCapability(1, firstDimension.id);
      await tester.pumpAndSettle();
      expect(
        dashboardNotifier.data.applicationDomains.first.capabilityIds,
        contains(firstDimension.id),
      );

      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CapabilityApplicationMatrix(
                dimensions: dashboardNotifier.data.dimensions,
                domains: dashboardNotifier.data.applicationDomains,
                maxScore: dashboardNotifier.data.maxScore,
                onToggleCapabilityLink: dashboardNotifier.toggleDomainCapability,
                submitEnabled: false,
                onSubmit: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cellInkWells = _findDataCellInkWells();
      await tester.tap(cellInkWells.first);
      await tester.pumpAndSettle();

      expect(
        dashboardNotifier.data.applicationDomains.first.capabilityIds,
        isNot(contains(firstDimension.id)),
      );
      expect(
        linkedDomainCount(
          firstDimension.id,
          dashboardNotifier.data.applicationDomains,
        ),
        0,
      );
    });

    testWidgets('N/A domain cells are not interactive', (tester) async {
      const dimension = Dimension(
        id: 1,
        name: 'Prompt Engineering',
        score: 3.0,
        color: '#2563EB',
        descriptor: 'Test descriptor',
      );
      final naDomain = ApplicationDomain(
        id: 99,
        name: 'Legacy Domain',
        shortName: 'Legacy',
        applicability: DomainApplicability.notApplicable,
        involvement: DomainInvolvement.none,
        value: DomainSignal.low,
        confidence: DomainSignal.low,
        capabilityIds: const [],
      );

      int toggleCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapabilityApplicationMatrix(
              dimensions: const [dimension],
              domains: [naDomain],
              maxScore: 5,
              onToggleCapabilityLink: (domainId, capabilityId) {
                toggleCallCount++;
              },
              submitEnabled: false,
              onSubmit: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cellInkWells = _findDataCellInkWells();
      expect(cellInkWells, findsNothing);

      // Tapping the matrix area should not invoke the toggle callback, since
      // the only N/A domain has no tappable data cell.
      await tester.tap(find.byType(CapabilityApplicationMatrix));
      await tester.pumpAndSettle();
      expect(toggleCallCount, 0);
    });

    testWidgets('capability info icon opens definition dialog',
        (tester) async {
      const dimension = Dimension(
        id: 1,
        name: 'Prompt Engineering',
        score: 3.5,
        color: '#2563EB',
        descriptor: 'Intent specification and iterative refinement',
      );
      final domain = ApplicationDomain(
        id: 1,
        name: 'Discovery',
        shortName: 'Discovery',
        applicability: DomainApplicability.inScope,
        involvement: DomainInvolvement.occasional,
        value: DomainSignal.moderate,
        confidence: DomainSignal.moderate,
        capabilityIds: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CapabilityApplicationMatrix(
              dimensions: const [dimension],
              domains: [domain],
              maxScore: 5,
              submitEnabled: false,
              onSubmit: null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1. Prompt Engineering'), findsNothing);
      expect(find.text('Definition'), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text('1. Prompt Engineering'), findsOneWidget);
      expect(find.text('Definition'), findsOneWidget);
      expect(
        find.text('Intent specification and iterative refinement'),
        findsOneWidget,
      );
      expect(find.text('Score: 3.5 / 5'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('1. Prompt Engineering'), findsNothing);
    });
  });

  group('SDLCTab matrix', () {
    testWidgets('explanation card appears before the matrix card',
        (tester) async {
      final dashboardNotifier = DashboardNotifier.forTesting();
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'fake-token',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
            ChangeNotifierProvider.value(value: dashboardNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SDLCTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final explanationFinder = find.text('How to Read — Capability × Domain');
      final matrixFinder = find.text('Capability × Domain Links');
      expect(explanationFinder, findsOneWidget);
      expect(matrixFinder, findsOneWidget);

      final explanationOffset = tester.getTopLeft(explanationFinder);
      final matrixOffset = tester.getTopLeft(matrixFinder);
      expect(explanationOffset.dy, lessThan(matrixOffset.dy));
    });
  });
}
