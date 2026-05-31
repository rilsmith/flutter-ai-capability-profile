import 'package:flutter/material.dart';

import '../models/dimension.dart';
import '../theme/dashboard_theme.dart';

class DimensionScoresCard extends StatelessWidget {
  const DimensionScoresCard({
    super.key,
    required this.dimensions,
    required this.average,
    required this.maxScore,
    this.selectedDimensionId,
    this.onSelectDimension,
    this.fillHeight = false,
  });

  final List<Dimension> dimensions;
  final double average;
  final int maxScore;
  final int? selectedDimensionId;
  final ValueChanged<int>? onSelectDimension;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fillHeight ? double.infinity : null,
      height: fillHeight ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dimension Scores', style: DashboardTheme.cardHeading),
          const SizedBox(height: 8),
          for (final dimension in dimensions) ...[
            _ScoreRow(
              dimension: dimension,
              selected: selectedDimensionId == dimension.id,
              onTap: onSelectDimension == null
                  ? null
                  : () => onSelectDimension!(dimension.id),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: DashboardTheme.cardBorder, height: 1),
          const SizedBox(height: 14),
          Text(
            'Average Score: $average / $maxScore',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.primary,
            ),
          ),
        ],
      ),
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
            dimension.score.toFixed(1),
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
                  border: Border.all(
                    color: const Color(0x332563EB),
                  ),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: content,
        ),
      ),
    );
  }
}

extension on double {
  String toFixed(int fractionDigits) => toStringAsFixed(fractionDigits);
}
