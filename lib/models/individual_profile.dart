class IndividualProfile {
  const IndividualProfile({
    required this.name,
    required this.scores,
  });

  final String name;
  final List<double> scores;

  IndividualProfile copyWith({
    String? name,
    List<double>? scores,
  }) {
    return IndividualProfile(
      name: name ?? this.name,
      scores: scores ?? this.scores,
    );
  }

  factory IndividualProfile.fromJson(Map<String, dynamic> json) {
    return IndividualProfile(
      name: json['name'] as String,
      scores: (json['scores'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'scores': scores,
      };
}