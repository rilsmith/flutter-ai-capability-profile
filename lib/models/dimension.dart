class Dimension {
  const Dimension({
    required this.id,
    required this.name,
    required this.score,
    required this.color,
    required this.descriptor,
  });

  final int id;
  final String name;
  final double score;
  final String color;
  final String descriptor;

  Dimension copyWith({
    int? id,
    String? name,
    double? score,
    String? color,
    String? descriptor,
  }) {
    return Dimension(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      color: color ?? this.color,
      descriptor: descriptor ?? this.descriptor,
    );
  }

  factory Dimension.fromJson(Map<String, dynamic> json) {
    return Dimension(
      id: json['id'] as int,
      name: json['name'] as String,
      score: (json['score'] as num).toDouble(),
      color: json['color'] as String,
      descriptor: json['descriptor'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'score': score,
        'color': color,
        'descriptor': descriptor,
      };
}
