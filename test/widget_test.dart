import 'package:flutter_test/flutter_test.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/models/application_domain.dart';
import 'package:ai_capability_dashboard/utils/application.dart';
import 'package:ai_capability_dashboard/utils/migrate_application_domains.dart';

void main() {
  test('migrateApplicationDomains merges legacy stakeholder and program', () {
    final base = defaultDashboardData.applicationDomains;
    final legacy = [
      ...base.sublist(0, 8),
      ApplicationDomain(
        id: 9,
        name: 'Stakeholder Communication',
        shortName: 'Stakeholders',
        applicability: DomainApplicability.notApplicable,
        involvement: DomainInvolvement.none,
        value: DomainSignal.low,
        confidence: DomainSignal.low,
        capabilityIds: const [],
      ),
      ApplicationDomain(
        id: 10,
        name: 'Program / Project Coordination',
        shortName: 'Program',
        applicability: DomainApplicability.inScope,
        involvement: DomainInvolvement.occasional,
        value: DomainSignal.moderate,
        confidence: DomainSignal.moderate,
        capabilityIds: const [8],
      ),
    ];

    final migrated = migrateApplicationDomains(legacy, base);

    expect(migrated.length, 9);
    expect(migrated.last.shortName, 'Coordination');
    expect(migrated.last.applicability, DomainApplicability.inScope);
    expect(migrated.last.involvement, DomainInvolvement.occasional);
    expect(migrated.last.capabilityIds, contains(8));
  });

  test('computeApplicationBreadth counts in-scope domains', () {
    final breadth = computeApplicationBreadth(
      defaultDashboardData.applicationDomains,
    );

    expect(breadth.inScopeCount, 9);
    expect(breadth.activeCount, greaterThan(0));
  });
}
