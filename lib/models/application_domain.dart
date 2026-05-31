enum DomainApplicability { inScope, notApplicable }

enum DomainInvolvement { none, occasional, regular }

enum DomainSignal { low, moderate, high }

class ApplicationDomain {
  const ApplicationDomain({
    required this.id,
    required this.name,
    required this.shortName,
    required this.applicability,
    required this.involvement,
    required this.value,
    required this.confidence,
    required this.capabilityIds,
  });

  final int id;
  final String name;
  final String shortName;
  final DomainApplicability applicability;
  final DomainInvolvement involvement;
  final DomainSignal value;
  final DomainSignal confidence;
  final List<int> capabilityIds;

  bool get isNotApplicable => applicability == DomainApplicability.notApplicable;

  ApplicationDomain copyWith({
    int? id,
    String? name,
    String? shortName,
    DomainApplicability? applicability,
    DomainInvolvement? involvement,
    DomainSignal? value,
    DomainSignal? confidence,
    List<int>? capabilityIds,
  }) {
    return ApplicationDomain(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      applicability: applicability ?? this.applicability,
      involvement: involvement ?? this.involvement,
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      capabilityIds: capabilityIds ?? this.capabilityIds,
    );
  }

  factory ApplicationDomain.fromJson(Map<String, dynamic> json) {
    return ApplicationDomain(
      id: json['id'] as int,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      applicability: _applicabilityFromJson(json['applicability'] as String),
      involvement: _involvementFromJson(json['involvement'] as String),
      value: _signalFromJson(json['value'] as String),
      confidence: _signalFromJson(json['confidence'] as String),
      capabilityIds: (json['capabilityIds'] as List<dynamic>)
          .map((id) => id as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'applicability': _applicabilityToJson(applicability),
        'involvement': _involvementToJson(involvement),
        'value': _signalToJson(value),
        'confidence': _signalToJson(confidence),
        'capabilityIds': capabilityIds,
      };
}

class ApplicationBreadth {
  const ApplicationBreadth({
    required this.inScopeCount,
    required this.activeCount,
    required this.regularCount,
    required this.notApplicableCount,
  });

  final int inScopeCount;
  final int activeCount;
  final int regularCount;
  final int notApplicableCount;
}

DomainApplicability _applicabilityFromJson(String value) {
  return value == 'not_applicable'
      ? DomainApplicability.notApplicable
      : DomainApplicability.inScope;
}

String _applicabilityToJson(DomainApplicability value) {
  return value == DomainApplicability.notApplicable
      ? 'not_applicable'
      : 'in_scope';
}

DomainInvolvement _involvementFromJson(String value) {
  switch (value) {
    case 'regular':
      return DomainInvolvement.regular;
    case 'occasional':
      return DomainInvolvement.occasional;
    default:
      return DomainInvolvement.none;
  }
}

String _involvementToJson(DomainInvolvement value) {
  switch (value) {
    case DomainInvolvement.regular:
      return 'regular';
    case DomainInvolvement.occasional:
      return 'occasional';
    case DomainInvolvement.none:
      return 'none';
  }
}

DomainSignal _signalFromJson(String value) {
  switch (value) {
    case 'high':
      return DomainSignal.high;
    case 'moderate':
      return DomainSignal.moderate;
    default:
      return DomainSignal.low;
  }
}

String _signalToJson(DomainSignal value) {
  switch (value) {
    case DomainSignal.high:
      return 'high';
    case DomainSignal.moderate:
      return 'moderate';
    case DomainSignal.low:
      return 'low';
  }
}
