class MaturityLevel {
  const MaturityLevel({
    required this.level,
    required this.label,
    required this.color,
    required this.description,
  });

  final int level;
  final String label;
  final String color;
  final String description;

  factory MaturityLevel.fromJson(Map<String, dynamic> json) {
    return MaturityLevel(
      level: json['level'] as int,
      label: json['label'] as String,
      color: json['color'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'label': label,
        'color': color,
        'description': description,
      };
}
