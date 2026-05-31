import 'dimension.dart';
import 'maturity_level.dart';
import 'application_domain.dart';
import 'tier.dart';

class DashboardData {
  const DashboardData({
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.dimensions,
    required this.applicationDomains,
    required this.maturityScale,
    required this.howToRead,
    required this.applicationHowToRead,
    required this.applicationMatrixHowToRead,
    required this.tiers,
    required this.maxScore,
  });

  final String title;
  final String subtitle;
  final String intro;
  final List<Dimension> dimensions;
  final List<ApplicationDomain> applicationDomains;
  final List<MaturityLevel> maturityScale;
  final String howToRead;
  final String applicationHowToRead;
  final String applicationMatrixHowToRead;
  final TierGroup tiers;
  final int maxScore;

  DashboardData copyWith({
    String? title,
    String? subtitle,
    String? intro,
    List<Dimension>? dimensions,
    List<ApplicationDomain>? applicationDomains,
    List<MaturityLevel>? maturityScale,
    String? howToRead,
    String? applicationHowToRead,
    String? applicationMatrixHowToRead,
    TierGroup? tiers,
    int? maxScore,
  }) {
    return DashboardData(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      intro: intro ?? this.intro,
      dimensions: dimensions ?? this.dimensions,
      applicationDomains: applicationDomains ?? this.applicationDomains,
      maturityScale: maturityScale ?? this.maturityScale,
      howToRead: howToRead ?? this.howToRead,
      applicationHowToRead: applicationHowToRead ?? this.applicationHowToRead,
      applicationMatrixHowToRead:
          applicationMatrixHowToRead ?? this.applicationMatrixHowToRead,
      tiers: tiers ?? this.tiers,
      maxScore: maxScore ?? this.maxScore,
    );
  }

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      intro: json['intro'] as String? ?? '',
      dimensions: (json['dimensions'] as List<dynamic>)
          .map((item) => Dimension.fromJson(item as Map<String, dynamic>))
          .toList(),
      applicationDomains: json['applicationDomains'] == null
          ? const []
          : (json['applicationDomains'] as List<dynamic>)
              .map(
                (item) =>
                    ApplicationDomain.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      maturityScale: (json['maturityScale'] as List<dynamic>)
          .map((item) => MaturityLevel.fromJson(item as Map<String, dynamic>))
          .toList(),
      howToRead: json['howToRead'] as String,
      applicationHowToRead: json['applicationHowToRead'] as String? ?? '',
      applicationMatrixHowToRead:
          json['applicationMatrixHowToRead'] as String? ?? '',
      tiers: TierGroup.fromJson(json['tiers'] as Map<String, dynamic>),
      maxScore: json['maxScore'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'intro': intro,
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
        'applicationDomains':
            applicationDomains.map((d) => d.toJson()).toList(),
        'maturityScale': maturityScale.map((m) => m.toJson()).toList(),
        'howToRead': howToRead,
        'applicationHowToRead': applicationHowToRead,
        'applicationMatrixHowToRead': applicationMatrixHowToRead,
        'tiers': tiers.toJson(),
        'maxScore': maxScore,
      };
}
