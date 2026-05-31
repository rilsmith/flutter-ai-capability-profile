import '../models/application_domain.dart';

const _involvementRank = {
  DomainInvolvement.none: 0,
  DomainInvolvement.occasional: 1,
  DomainInvolvement.regular: 2,
};

const _signalRank = {
  DomainSignal.low: 0,
  DomainSignal.moderate: 1,
  DomainSignal.high: 2,
};

DomainInvolvement _higherInvolvement(DomainInvolvement a, DomainInvolvement b) {
  return _involvementRank[a]! >= _involvementRank[b]! ? a : b;
}

DomainSignal _higherSignal(DomainSignal a, DomainSignal b) {
  return _signalRank[a]! >= _signalRank[b]! ? a : b;
}

ApplicationDomain _mergeCoordinationFromLegacy(
  ApplicationDomain target,
  ApplicationDomain? stakeholder,
  ApplicationDomain? program,
) {
  final sources = [stakeholder, program].whereType<ApplicationDomain>().toList();
  if (sources.isEmpty) return target;

  final applicability = sources.any(
        (d) => d.applicability == DomainApplicability.inScope,
      )
      ? DomainApplicability.inScope
      : DomainApplicability.notApplicable;

  var involvement = DomainInvolvement.none;
  var value = target.value;
  var confidence = target.confidence;
  final capabilityIds = <int>{};

  for (final source in sources) {
    involvement = _higherInvolvement(involvement, source.involvement);
    value = _higherSignal(value, source.value);
    confidence = _higherSignal(confidence, source.confidence);
    capabilityIds.addAll(source.capabilityIds);
  }

  return target.copyWith(
    applicability: applicability,
    involvement: involvement,
    value: value,
    confidence: confidence,
    capabilityIds: capabilityIds.toList()..sort(),
  );
}

bool _isCurrentDomainSet(List<ApplicationDomain> domains) {
  return domains.length == 9 &&
      domains.any((d) => d.id == 9 && d.shortName == 'Coordination') &&
      !domains.any((d) => d.id == 10);
}

List<ApplicationDomain> migrateApplicationDomains(
  List<ApplicationDomain>? parsed,
  List<ApplicationDomain> defaults,
) {
  if (parsed == null || parsed.isEmpty) return defaults;
  if (_isCurrentDomainSet(parsed)) return parsed;

  final byId = {for (final d in parsed) d.id: d};
  final byShortName = {for (final d in parsed) d.shortName: d};

  final stakeholder = byId[9] ?? byShortName['Stakeholders'];
  final program = byId[10] ?? byShortName['Program'];

  return defaults.map((def) {
    if (def.id == 9) {
      return _mergeCoordinationFromLegacy(def, stakeholder, program);
    }

    final existing = byId[def.id];
    if (existing == null) return def;

    return def.copyWith(
      applicability: existing.applicability,
      involvement: existing.involvement,
      value: existing.value,
      confidence: existing.confidence,
      capabilityIds: existing.capabilityIds,
    );
  }).toList();
}
