import '../models/application_domain.dart';
import '../models/dimension.dart';
import '../models/tier.dart';
import 'application_sync.dart';

ApplicationBreadth computeApplicationBreadth(List<ApplicationDomain> domains) {
  final inScope =
      domains.where((d) => d.applicability == DomainApplicability.inScope);
  final active =
      inScope.where((d) => d.involvement != DomainInvolvement.none);

  return ApplicationBreadth(
    inScopeCount: inScope.length,
    activeCount: active.length,
    regularCount: inScope
        .where((d) => d.involvement == DomainInvolvement.regular)
        .length,
    notApplicableCount: domains.length - inScope.length,
  );
}

List<Dimension> _highCapabilityDimensions(
  List<Dimension> dimensions,
  TierGroup tiers,
) {
  return dimensions.where((d) => d.score >= tiers.high.min).toList();
}

List<String> computeProfileInsights(
  List<Dimension> dimensions,
  List<ApplicationDomain> domains,
  TierGroup tiers,
) {
  final insights = <String>[];
  final breadth = computeApplicationBreadth(domains);
  final inScope =
      domains.where((d) => d.applicability == DomainApplicability.inScope).toList();
  final active =
      inScope.where((d) => d.involvement != DomainInvolvement.none).toList();
  final highCaps = _highCapabilityDimensions(dimensions, tiers);
  final avgScore =
      dimensions.fold<double>(0, (sum, d) => sum + d.score) / dimensions.length;

  if (breadth.inScopeCount > 0) {
    insights.add(
      'Agent use reported in ${breadth.activeCount} of ${breadth.inScopeCount} in-scope lifecycle domains (${breadth.regularCount} regular).',
    );
  }

  final useWithoutLinks = inScope
      .where(
        (d) =>
            d.involvement != DomainInvolvement.none &&
            d.capabilityIds.isEmpty,
      )
      .toList();
  if (useWithoutLinks.isNotEmpty) {
    final names = useWithoutLinks.take(2).map((d) => d.shortName).join(', ');
    final suffix = useWithoutLinks.length > 2 ? ', and others' : '';
    insights.add(
      '$names$suffix: agent use reported but no capabilities linked yet.',
    );
  }

  final linksWithoutUse = inScope
      .where(
        (d) =>
            d.involvement == DomainInvolvement.none &&
            d.capabilityIds.isNotEmpty,
      )
      .toList();
  if (linksWithoutUse.isNotEmpty) {
    insights.add(
      '${linksWithoutUse.first.shortName} has capability links but agent use is marked Never — past experimentation or planned use.',
    );
  }

  final focusedRegular = inScope.where(isFocusedRegularUse).toList();
  if (focusedRegular.isNotEmpty) {
    final domain = focusedRegular.first;
    insights.add(
      'Regular agent use in ${domain.shortName} with a focused set of ${domain.capabilityIds.length} capabilities — deep habit, narrow pattern.',
    );
  }

  final broadOccasional = inScope.where(isBroadOccasionalExperiment).toList();
  if (broadOccasional.isNotEmpty && linksWithoutUse.isEmpty) {
    insights.add(
      '${broadOccasional.first.shortName}: many capabilities linked but use is occasional — broad exploration, not yet habitual.',
    );
  }

  final divergent = inScope.where(domainHasInvolvementLinkDivergence).toList();
  if (divergent.isNotEmpty &&
      useWithoutLinks.isEmpty &&
      linksWithoutUse.isEmpty) {
    if (divergent.length >= 3) {
      insights.add(
        '${divergent.length} domains (including ${divergent.first.shortName}) show different involvement and capability-link patterns — review strip and matrix together for nuance.',
      );
    } else {
      insights.add(
        '${divergent.first.shortName} shows a mismatch between agent involvement and capability links — check the matrix to see which capabilities anchor this domain.',
      );
    }
  }

  if (highCaps.isNotEmpty && active.isNotEmpty) {
    final narrowHighCaps = highCaps.where((cap) {
      final linked = active
          .where((d) => d.capabilityIds.contains(cap.id))
          .length;
      return linked <= (active.length / 3).floor().clamp(1, active.length);
    }).toList();

    if (narrowHighCaps.isNotEmpty) {
      final names = narrowHighCaps.take(2).map((d) => d.name).join(', ');
      final suffix = narrowHighCaps.length > 2 ? ', and others' : '';
      insights.add(
        'Strong capabilities ($names$suffix) appear in a narrow set of active domains — potential to transfer patterns elsewhere.',
      );
    }
  }

  final latent = highCaps.where((cap) {
    return active.every((d) => !d.capabilityIds.contains(cap.id));
  }).toList();
  if (latent.isNotEmpty) {
    final names = latent.take(2).map((d) => d.name).join(', ');
    final suffix = latent.length > 2 ? ', and others' : '';
    insights.add(
      '$names$suffix: rated highly but not linked to any active domain yet — potential latent strength.',
    );
  }

  if (avgScore >= tiers.high.min &&
      breadth.activeCount >= (breadth.inScopeCount * 0.6).ceil()) {
    insights.add(
      'Capability and application breadth both span most of your in-scope work — a systemic agentic practice profile.',
    );
  } else if (avgScore >= tiers.medium.min &&
      breadth.activeCount >= (breadth.inScopeCount * 0.5).ceil()) {
    insights.add(
      'Broad application with developing capability depth — experimentation is spread across the lifecycle.',
    );
  } else if (avgScore >= tiers.high.min &&
      breadth.activeCount <= (breadth.inScopeCount / 3).ceil()) {
    insights.add(
      'Deep capability concentration in a focused set of domains — a specialist application profile.',
    );
  }

  Dimension? reliability;
  for (final dimension in dimensions) {
    if (dimension.name.contains('Evaluation')) {
      reliability = dimension;
      break;
    }
  }
  if (reliability != null && reliability.score >= tiers.high.min) {
    final reliabilityId = reliability.id;
    final reliabilityDomains = active
        .where((d) => d.capabilityIds.contains(reliabilityId))
        .map((d) => d.shortName)
        .toList();
    if (reliabilityDomains.length == 1) {
      insights.add(
        'Evaluation & Verification shows up only in ${reliabilityDomains.first} — consider whether testing, eval, or quality contexts apply.',
      );
    }
  }

  return insights.take(6).toList();
}

String involvementLabel(DomainInvolvement involvement) {
  switch (involvement) {
    case DomainInvolvement.regular:
      return 'Regular';
    case DomainInvolvement.occasional:
      return 'Occasional';
    case DomainInvolvement.none:
      return 'Never';
  }
}

String signalLabel(DomainSignal signal) {
  switch (signal) {
    case DomainSignal.high:
      return 'High';
    case DomainSignal.moderate:
      return 'Moderate';
    case DomainSignal.low:
      return 'Low';
  }
}

bool isCapabilityLinked(ApplicationDomain domain, int capabilityId) {
  return domain.capabilityIds.contains(capabilityId);
}

int linkedDomainCount(int capabilityId, List<ApplicationDomain> domains) {
  return domains
      .where(
        (d) =>
            d.applicability == DomainApplicability.inScope &&
            d.capabilityIds.contains(capabilityId),
      )
      .length;
}

String profileShapeLabel(
  List<Dimension> dimensions,
  List<ApplicationDomain> domains,
  TierGroup tiers,
) {
  final avgScore =
      dimensions.fold<double>(0, (sum, d) => sum + d.score) / dimensions.length;
  final breadth = computeApplicationBreadth(domains);
  final highCapability = avgScore >= tiers.high.min;
  final broadApplication = breadth.inScopeCount > 0 &&
      breadth.activeCount >= (breadth.inScopeCount * 0.6).ceil();

  if (highCapability && broadApplication) return 'Capable integrator';
  if (highCapability && !broadApplication) return 'Deep specialist';
  if (!highCapability && broadApplication) return 'Capable explorer';
  return 'Focused adopter';
}
