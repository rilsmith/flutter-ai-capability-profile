import '../models/application_domain.dart';

DomainInvolvement cycleInvolvement(DomainInvolvement current) {
  switch (current) {
    case DomainInvolvement.none:
      return DomainInvolvement.occasional;
    case DomainInvolvement.occasional:
      return DomainInvolvement.regular;
    case DomainInvolvement.regular:
      return DomainInvolvement.none;
  }
}

List<int> toggleCapabilityIds(ApplicationDomain domain, int capabilityId) {
  if (domain.capabilityIds.contains(capabilityId)) {
    return domain.capabilityIds.where((id) => id != capabilityId).toList();
  }
  return [...domain.capabilityIds, capabilityId]..sort();
}

ApplicationDomain domainWhenApplicabilityChanges(
  DomainApplicability applicability,
  ApplicationDomain domain,
) {
  if (applicability == DomainApplicability.notApplicable) {
    return domain.copyWith(
      applicability: applicability,
      involvement: DomainInvolvement.none,
      capabilityIds: const [],
    );
  }
  return domain.copyWith(
    applicability: applicability,
    involvement: DomainInvolvement.none,
    capabilityIds: const [],
  );
}

bool domainHasInvolvementLinkDivergence(ApplicationDomain domain) {
  if (domain.isNotApplicable) return false;
  final hasLinks = domain.capabilityIds.isNotEmpty;
  final hasUse = domain.involvement != DomainInvolvement.none;
  return hasUse != hasLinks;
}

bool isFocusedRegularUse(ApplicationDomain domain) {
  return !domain.isNotApplicable &&
      domain.involvement == DomainInvolvement.regular &&
      domain.capabilityIds.isNotEmpty &&
      domain.capabilityIds.length <= 3;
}

bool isBroadOccasionalExperiment(ApplicationDomain domain) {
  return !domain.isNotApplicable &&
      domain.involvement == DomainInvolvement.occasional &&
      domain.capabilityIds.length >= 5;
}
