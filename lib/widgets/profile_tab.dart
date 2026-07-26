import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/compute.dart';
import '../utils/application.dart';
import '../data/style_lens_config.dart';
import '../utils/style_lens.dart';
import 'capability_profile_card.dart';
import 'profile_insights_card.dart';
import 'style_lens_panel.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;
    final average = computeAverage(data.dimensions);
    final distribution = computeDistribution(data.dimensions, data.tiers);
    final insights = computeProfileInsights(
      data.dimensions,
      data.applicationDomains,
      data.tiers,
    );
    final styleLens = computeStyleLens(
      data.dimensions,
      tiers: data.tiers,
      maxScore: data.maxScore,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Profile Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aggregate capability scores, distribution, engineering style, and strategic insights.',
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 20),
          CapabilityProfileCard(
            dimensions: data.dimensions,
            average: average,
            maxScore: data.maxScore,
            distribution: distribution,
            tiers: data.tiers,
            maturityScale: data.maturityScale,
            selectedDimensionId: null,
            onSelectDimension: null,
          ),
          const SizedBox(height: 20),
          StyleLensPanel(
            analysis: styleLens,
            config: styleLensConfig,
            maxScore: data.maxScore,
          ),
          const SizedBox(height: 20),
          ProfileInsightsCard(insights: insights),
        ],
      ),
    );
  }
}