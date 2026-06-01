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
    );
    final scores = _ProfileScores(
      dimensions: dimensions,
      selectedDimensionId: selectedDimensionId,
      onSelectDimension: onSelectDimension,
    );
    final scale = _MaturityScale(maturityScale: maturityScale);

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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: DashboardTheme.divider, height: 1),
                ),
                scale,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 260, child: sidebar),
                const SizedBox(width: 24),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(left: 24),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: DashboardTheme.divider, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        scores,
                        const SizedBox(height: 32),
                        const Divider(color: DashboardTheme.divider, height: 1),
                        const SizedBox(height: 24),
                        scale,
                      ],
                    ),
                  ),
                ),
              ],
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
  });

  final double average;
  final int maxScore;
  final Distribution distribution;
  final TierGroup tiers;

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
          style: TextStyle(fontSize: 14, color: DashboardTheme.muted),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.primary,
              height: 1.1,
            ),
            children: [
              TextSpan(text: '$average '),
              TextSpan(
                text: '/ $maxScore',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: DashboardTheme.subtle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Capability Distribution',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DashboardTheme.body,
          ),
        ),
        const SizedBox(height: 12),
        for (final row in distributionRows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                      fontSize: 14,
                      color: DashboardTheme.body,
                    ),
                  ),
                ),
                Text(
                  '${row.count}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.heading,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MaturityScale extends StatelessWidget {
  const _MaturityScale({required this.maturityScale});
  final List<MaturityLevel> maturityScale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Capability Scale (1–5)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DashboardTheme.body,
          ),
        ),
        const SizedBox(height: 12),
        for (final level in maturityScale)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    '${level.level} – ${level.label}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DashboardTheme.parseHex(level.color),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    level.description,
                    style: const TextStyle(
                      fontSize: 13,
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
    final width = MediaQuery.sizeOf(context).width;
    // Sidebar 260 + Paddings/Dividers ~100 = 360.
    // If width > 1100, we have > 740 for scores, enough for 2 columns.
    final useTwoColumns = width > 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dimension Scores',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DashboardTheme.body,
          ),
        ),
        const SizedBox(height: 12),
        if (!useTwoColumns)
          for (final dimension in dimensions)
            _ScoreRow(
              dimension: dimension,
              selected: selectedDimensionId == dimension.id,
              onTap: onSelectDimension == null
                  ? null
                  : () => onSelectDimension!(dimension.id),
            )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < (dimensions.length / 2).ceil(); i++)
                      _ScoreRow(
                        dimension: dimensions[i],
                        selected: selectedDimensionId == dimensions[i].id,
                        onTap: onSelectDimension == null
                            ? null
                            : () => onSelectDimension!(dimensions[i].id),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  children: [
                    for (var i = (dimensions.length / 2).ceil();
                        i < dimensions.length;
                        i++)
                      _ScoreRow(
                        dimension: dimensions[i],
                        selected: selectedDimensionId == dimensions[i].id,
                        onTap: onSelectDimension == null
                            ? null
                            : () => onSelectDimension!(dimensions[i].id),
                      ),
                  ],
                ),
              ),
            ],
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${dimension.id}. ${dimension.name}',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: DashboardTheme.parseHex(dimension.color),
              height: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 1,
              child: CustomPaint(
                painter: _DottedLinePainter(
                  color: DashboardTheme.subtle.withOpacity(0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            dimension.score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13.5,
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

class _DottedLinePainter extends CustomPainter {
  _DottedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 1.0;
    const dashSpace = 3.0;
    double startX = 0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
