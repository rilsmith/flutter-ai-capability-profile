import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class ProfileInsightsCard extends StatelessWidget {
  const ProfileInsightsCard({super.key, required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Insights', style: DashboardTheme.cardHeading),
          const SizedBox(height: 8),
          const Text(
            'Patterns from combining capability strength and application breadth — descriptive, not a score on a linear path.',
            style: TextStyle(
              fontSize: 13,
              color: DashboardTheme.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            const Text(
              'No aggregate insights available for the current team data.',
              style: TextStyle(
                fontSize: 13,
                color: DashboardTheme.muted,
                height: 1.5,
              ),
            )
          else
            ...insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 13,
                        color: DashboardTheme.body,
                        height: 1.5,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        insight,
                        style: const TextStyle(
                          fontSize: 13,
                          color: DashboardTheme.body,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
