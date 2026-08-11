import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/models/dimension.dart';
import 'package:ai_capability_dashboard/models/individual_profile.dart';
import 'package:ai_capability_dashboard/models/team_profile.dart';
import 'package:ai_capability_dashboard/providers/auth_notifier.dart';
import 'package:ai_capability_dashboard/providers/dashboard_notifier.dart';
import 'package:ai_capability_dashboard/providers/team_notifier.dart';
import 'package:ai_capability_dashboard/utils/application.dart';
import 'package:ai_capability_dashboard/widgets/capability_profile_card.dart';
import 'package:ai_capability_dashboard/widgets/profile_insights_card.dart';
import 'package:ai_capability_dashboard/widgets/profile_tab.dart';
import 'package:ai_capability_dashboard/widgets/style_lens_panel.dart';

List<Dimension> _aggregateDimensions() {
  return defaultDashboardData.dimensions.map((d) {
    return Dimension(
      id: d.id,
      name: d.name,
      score: d.id == 1 ? 4.5 : 3.0,
      color: d.color,
      descriptor: d.descriptor,
    );
  }).toList();
}

List<ApplicationDomain> _aggregateDomains() {
  return defaultDashboardData.applicationDomains.map((d) {
    return ApplicationDomain(
      id: d.id,
      name: d.name,
      shortName: d.shortName,
      applicability: DomainApplicability.inScope,
      involvement: DomainInvolvement.regular,
      value: DomainSignal.moderate,
      confidence: DomainSignal.moderate,
      capabilityIds: const [1],
    );
  }).toList();
}

class _TeamNotifierSpy extends TeamNotifier {
  _TeamNotifierSpy() : super.forTesting();

  int fetchCallCount = 0;
  String? lastToken;
  bool? lastForce;

  @override
  Future<void> fetchTeamData(String token, {bool force = false}) async {
    fetchCallCount++;
    lastToken = token;
    lastForce = force;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileTab', () {
    testWidgets('renders loading state while fetching aggregate', (tester) async {
      final teamNotifier = TeamNotifier.forTesting();
      teamNotifier.debugSetLoading(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CapabilityProfileCard), findsNothing);
      expect(find.byType(StyleLensPanel), findsNothing);
      expect(find.byType(ProfileInsightsCard), findsNothing);
    });

    testWidgets('renders empty state when no team submissions exist', (tester) async {
      final teamNotifier = TeamNotifier.forTesting();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No team insights available yet'), findsOneWidget);
      expect(find.byType(CapabilityProfileCard), findsNothing);
      expect(find.byType(StyleLensPanel), findsNothing);
      expect(find.byType(ProfileInsightsCard), findsNothing);
    });

    testWidgets('renders error state with retry button', (tester) async {
      final teamNotifier = TeamNotifier.forTesting();
      teamNotifier.debugSetError('Failed to load team aggregate (500)');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthNotifier.forTesting(
                user: const GitHubUser(
                  login: 'testuser',
                  name: 'Test User',
                  email: 'testuser@example.com',
                  avatarUrl: '',
                ),
                token: 'fake-token',
              ),
            ),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load team insights'), findsOneWidget);
      expect(find.text('Failed to load team aggregate (500)'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CapabilityProfileCard), findsNothing);
      expect(find.byType(StyleLensPanel), findsNothing);
      expect(find.byType(ProfileInsightsCard), findsNothing);
    });

    testWidgets('renders capability profile, style lens, and insights from aggregate data', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        profile: TeamProfile(
          members: [
            IndividualProfile(name: 'Alice', scores: [4.5, 3, 3, 3, 3]),
          ],
        ),
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: _aggregateDomains(),
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CapabilityProfileCard), findsOneWidget);
      expect(find.byType(StyleLensPanel), findsOneWidget);
      expect(find.byType(ProfileInsightsCard), findsOneWidget);
      expect(find.text('No team insights available yet'), findsNothing);
      expect(find.text('Engineering Style Lens'), findsOneWidget);
      expect(find.text('Capability Profile'), findsOneWidget);
      // The ProfileInsightsCard heading is also "Profile Insights", so the
      // text appears in both the tab title and the card; use widget type.
      expect(find.byType(ProfileInsightsCard), findsOneWidget);

      // Average should reflect the aggregate dimension scores (4.5 + 3*4) / 5 = 3.3.
      final card = tester.widget<CapabilityProfileCard>(
        find.byType(CapabilityProfileCard),
      );
      expect(card.average, 3.3);
      // Dimension scores should show the aggregate value, not the default 3.0.
      expect(card.dimensions.firstWhere((d) => d.id == 1).score, 4.5);
    });

    testWidgets('does not use local dashboard data for scores', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: _aggregateDomains(),
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The aggregate average is 3.3, while the local default would be 3.0.
      final card = tester.widget<CapabilityProfileCard>(
        find.byType(CapabilityProfileCard),
      );
      expect(card.average, 3.3);
      // The first aggregate dimension is 4.5, while the local default is 3.0.
      expect(card.dimensions.firstWhere((d) => d.id == 1).score, 4.5);
    });

    testWidgets('does not render export or import controls', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: _aggregateDomains(),
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Export'), findsNothing);
      expect(find.textContaining('Import'), findsNothing);
      expect(find.textContaining('CSV'), findsNothing);
      expect(find.textContaining('JSON'), findsNothing);
    });

    testWidgets('retry action re-fetches team aggregate data', (tester) async {
      final authNotifier = AuthNotifier.forTesting(
        user: const GitHubUser(
          login: 'testuser',
          name: 'Test User',
          email: 'testuser@example.com',
          avatarUrl: '',
        ),
        token: 'test-token',
      );
      final teamSpy = _TeamNotifierSpy();
      teamSpy.debugSetError('Failed to load team aggregate (500)');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authNotifier),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider<TeamNotifier>.value(value: teamSpy),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load team insights'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(teamSpy.fetchCallCount, 0);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(teamSpy.fetchCallCount, 1);
      expect(teamSpy.lastToken, 'test-token');
      expect(teamSpy.lastForce, isTrue);
    });

    testWidgets('shows empty insight message when all domains are not applicable',
        (tester) async {
      final naDomains = defaultDashboardData.applicationDomains.map((d) {
        return ApplicationDomain(
          id: d.id,
          name: d.name,
          shortName: d.shortName,
          applicability: DomainApplicability.notApplicable,
          involvement: DomainInvolvement.none,
          value: DomainSignal.low,
          confidence: DomainSignal.low,
          capabilityIds: const [],
        );
      }).toList();

      final teamNotifier = TeamNotifier.forTesting(
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: naDomains,
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileInsightsCard), findsOneWidget);
      expect(
        find.text('No aggregate insights available for the current team data.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Agent use reported in 0 of 0'),
        findsNothing,
      );
    });

    testWidgets('renders all cards with a single-member team', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        profile: TeamProfile(
          members: [
            IndividualProfile(name: 'Alice', scores: [4.5, 3, 3, 3, 3]),
          ],
        ),
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: _aggregateDomains(),
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CapabilityProfileCard), findsOneWidget);
      expect(find.byType(StyleLensPanel), findsOneWidget);
      expect(find.byType(ProfileInsightsCard), findsOneWidget);
      expect(find.text('No team insights available yet'), findsNothing);

      final card = tester.widget<CapabilityProfileCard>(
        find.byType(CapabilityProfileCard),
      );
      expect(card.average, 3.3);
    });

    testWidgets('renders profile shape label from aggregate data', (tester) async {
      final teamNotifier = TeamNotifier.forTesting(
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: _aggregateDomains(),
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile Shape'), findsOneWidget);
      // Average 3.3 (< high threshold) and all domains active => Capable explorer.
      expect(find.text('Capable explorer'), findsOneWidget);
      final card = tester.widget<CapabilityProfileCard>(
        find.byType(CapabilityProfileCard),
      );
      expect(card.shapeLabel, 'Capable explorer');
    });

    testWidgets('renders profile shape fallback when no in-scope domains',
        (tester) async {
      final naDomains = defaultDashboardData.applicationDomains.map((d) {
        return ApplicationDomain(
          id: d.id,
          name: d.name,
          shortName: d.shortName,
          applicability: DomainApplicability.notApplicable,
          involvement: DomainInvolvement.none,
          value: DomainSignal.low,
          confidence: DomainSignal.low,
          capabilityIds: const [],
        );
      }).toList();

      final teamNotifier = TeamNotifier.forTesting(
        aggregateDimensions: _aggregateDimensions(),
        aggregateCoverageDomains: naDomains,
        aggregateMemberCount: 1,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthNotifier.forTesting()),
            ChangeNotifierProvider(create: (_) => DashboardNotifier.forTesting()),
            ChangeNotifierProvider.value(value: teamNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ProfileTab()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile Shape'), findsOneWidget);
      expect(find.text('Focused adopter'), findsOneWidget);
    });

    test('profileShapeLabel falls back to Focused adopter when no in-scope domains', () {
      final naDomains = defaultDashboardData.applicationDomains.map((d) {
        return ApplicationDomain(
          id: d.id,
          name: d.name,
          shortName: d.shortName,
          applicability: DomainApplicability.notApplicable,
          involvement: DomainInvolvement.none,
          value: DomainSignal.low,
          confidence: DomainSignal.low,
          capabilityIds: const [],
        );
      }).toList();

      final label = profileShapeLabel(
        _aggregateDimensions(),
        naDomains,
        defaultDashboardData.tiers,
      );
      expect(label, 'Focused adopter');
    });
  });
}
