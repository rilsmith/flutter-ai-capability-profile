import 'individual_profile.dart';

class TeamProfile {
  const TeamProfile({
    this.name = 'Team',
    this.members = const [],
  });

  final String name;
  final List<IndividualProfile> members;

  TeamProfile copyWith({
    String? name,
    List<IndividualProfile>? members,
  }) {
    return TeamProfile(
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }

  List<double> get averages {
    if (members.isEmpty) return List.filled(9, 0.0);
    final sums = List.filled(9, 0.0);
    for (final m in members) {
      for (var i = 0; i < m.scores.length && i < 9; i++) {
        sums[i] += m.scores[i];
      }
    }
    return sums.map((s) => (s / members.length * 10).roundToDouble() / 10).toList();
  }

  List<double> get mins {
    if (members.isEmpty) return List.filled(9, 0.0);
    final result = List.filled(9, double.infinity);
    for (final m in members) {
      for (var i = 0; i < m.scores.length && i < 9; i++) {
        if (m.scores[i] < result[i]) result[i] = m.scores[i];
      }
    }
    return result;
  }

  List<double> get maxs {
    if (members.isEmpty) return List.filled(9, 0.0);
    final result = List.filled(9, double.negativeInfinity);
    for (final m in members) {
      for (var i = 0; i < m.scores.length && i < 9; i++) {
        if (m.scores[i] > result[i]) result[i] = m.scores[i];
      }
    }
    return result;
  }

  factory TeamProfile.fromJson(Map<String, dynamic> json) {
    return TeamProfile(
      name: json['name'] as String? ?? 'Team',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) =>
                  IndividualProfile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
      };
}