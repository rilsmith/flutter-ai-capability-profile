import 'package:flutter/material.dart';

import '../models/distribution.dart';
import '../models/tier.dart';
import '../theme/dashboard_theme.dart';

class SnapshotCard extends StatelessWidget {
  const SnapshotCard({
    super.key,
    required this.average,
    required this.maxScore,
    required this.distribution,
    required this.tiers,
    this.fillHeight = false,
  });

  final double average;
  final int maxScore;
  final Distribution distribution;
  final TierGroup tiers;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (count: distribution.high, tier: tiers.high),
      (count: distribution.medium, tier: tiers.medium),
      (count: distribution.low, tier: tiers.low),
    ];

    return Container(
      width: fillHeight ? double.infinity : null,
      height: fillHeight ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overall Snapshot', style: DashboardTheme.cardHeading),
          const SizedBox(height: 16),
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
            'Capability Distribution',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.body,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows) ...[
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
          ],
        ],
      ),
    );
  }
}
