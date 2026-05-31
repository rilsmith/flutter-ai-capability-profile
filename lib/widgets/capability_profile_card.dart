import 'package:flutter/material.dart';

import '../models/dimension.dart';
import '../models/distribution.dart';
import '../models/maturity_level.dart';
import '../models/tier.dart';
import '../theme/dashboard_theme.dart';

class CapabilityProfileCard extends StatelessWidget {
  const CapabilityProfileCard({
    super.key,
    required this.dimensions,
    required this.average,
    required this.maxScore,
    required this.distribution,
    required this.tiers,
    required this.maturityScale,
    this.selectedDimensionId,
    this.onSelectDimension,
  });

  final List<Dimension> dimensions;
  final double average;
  final int maxScore;
  final Distribution distribution;
  final TierGroup tiers;
  final List<MaturityLevel> maturityScale;
  final int? selectedDimensionId;
  final ValueChanged<int>? onSelectDimension;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final stackSidebar = width <= 760;

    final sidebar = _ProfileSidebar(
      average: average,
      maxScore: maxScore,
      distribution: distribution,
      tiers: tiers,
      maturityScale: maturityScale,
    );
    final scores = _ProfileScores(
      dimensions: dimensions,
      selectedDimensionId: selectedDimensionId,
      onSelectDimension: onSelectDimension,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Capability Profile', style: DashboardTheme.cardHeading),
          const SizedBox(height: 20),
          if (stackSidebar)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                sidebar,
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: DashboardTheme.divider, height: 1),
                ),
                scores,
              ],
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 260, child: sidebar),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: VerticalDivider(
                      color: DashboardTheme.divider,
                      width: 1,
                    ),
                  ),
                  Expanded(child: scores),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileSidebar extends StatelessWidget {
  const _ProfileSidebar({
    required this.average,
    required this.maxScore,
    required this.distribution,
    required this.tiers,
    required this.maturityScale,
  });

  final double average;
  final int maxScore;
  final Distribution distribution;
  final TierGroup tiers;
  final List<MaturityLevel> maturityScale;

  @override
  Widget build(BuildContext context) {
    final distributionRows = [
      (count: distribution.high, tier: tiers.high),
      (count: distribution.medium, tier: tiers.medium),
      (count: distribution.low, tier: tiers.low),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Average Score',
          style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.primary,
              height: 1.1,
            ),
            children: [
              TextSpan(text: '$average '),
              TextSpan(
                text: '/ $maxScore',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: DashboardTheme.subtle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Maturity Distribution',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DashboardTheme.body,
          ),
        ),
        const SizedBox(height: 10),
        for (final row in distributionRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: DashboardTheme.parseHex(row.tier.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.tier.label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: DashboardTheme.body,
                    ),
                  ),
                ),
                Text(
                  '${row.count}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.heading,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Divider(color: DashboardTheme.cardBorder, height: 1),
        const SizedBox(height: 16),
        const Text(
          'Maturity Scale (1–5)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DashboardTheme.body,
          ),
        ),
        const SizedBox(height: 10),
        for (final level in maturityScale)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    '${level.level} – ${level.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DashboardTheme.parseHex(level.color),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    level.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DashboardTheme.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfileScores extends StatelessWidget {
  const _ProfileScores({
    required this.dimensions,
    required this.selectedDimensionId,
    required this.onSelectDimension,
  });

  final List<Dimension> dimensions;
  final int? selectedDimensionId;
  final ValueChanged<int>? onSelectDimension;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dimension Scores',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DashboardTheme.body,
          ),
        ),
        const SizedBox(height: 8),
        for (final dimension in dimensions)
          _ScoreRow(
            dimension: dimension,
            selected: selectedDimensionId == dimension.id,
            onTap: onSelectDimension == null
                ? null
                : () => onSelectDimension!(dimension.id),
          ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.dimension,
    required this.selected,
    this.onTap,
  });

  final Dimension dimension;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              '${dimension.id}. ${dimension.name}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: DashboardTheme.parseHex(dimension.color),
                height: 1.3,
              ),
            ),
          ),
          Text(
            dimension.score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: selected ? DashboardTheme.primaryLight : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: const Color(0xFFF9FAFB),
        child: Container(
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x332563EB)),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: content,
        ),
      ),
    );
  }
}
