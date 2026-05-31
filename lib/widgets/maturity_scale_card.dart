import 'package:flutter/material.dart';

import '../models/maturity_level.dart';
import '../theme/dashboard_theme.dart';

class MaturityScaleCard extends StatelessWidget {
  const MaturityScaleCard({super.key, required this.levels});

  final List<MaturityLevel> levels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Maturity Scale (1–5)', style: DashboardTheme.cardHeading),
          const SizedBox(height: 16),
          for (final level in levels)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
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
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
