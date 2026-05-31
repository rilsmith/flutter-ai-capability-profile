class Tier {
  const Tier({
    required this.label,
    required this.color,
    required this.min,
  });

  final String label;
  final String color;
  final double min;

  factory Tier.fromJson(Map<String, dynamic> json) {
    return Tier(
      label: json['label'] as String,
      color: json['color'] as String,
      min: (json['min'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'color': color,
        'min': min,
      };
}

class TierGroup {
  const TierGroup({
    required this.high,
    required this.medium,
    required this.low,
  });

  final Tier high;
  final Tier medium;
  final Tier low;

  factory TierGroup.fromJson(Map<String, dynamic> json) {
    return TierGroup(
      high: Tier.fromJson(json['high'] as Map<String, dynamic>),
      medium: Tier.fromJson(json['medium'] as Map<String, dynamic>),
      low: Tier.fromJson(json['low'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'high': high.toJson(),
        'medium': medium.toJson(),
        'low': low.toJson(),
      };
}
