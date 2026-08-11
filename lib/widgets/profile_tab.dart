import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/application_domain.dart';
import '../models/dashboard_data.dart';
import '../models/dimension.dart';
import '../providers/auth_notifier.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/team_notifier.dart';
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
    final teamNotifier = context.watch<TeamNotifier>();
    final dashboardNotifier = context.read<DashboardNotifier>();
    final data = dashboardNotifier.data;
    final dimensions = teamNotifier.aggregateDimensions;
    final domains = teamNotifier.aggregateCoverageDomains;

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
            'Aggregate capability scores, distribution, engineering style, and strategic insights — derived from the team’s latest submissions.',
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 20),
          if (teamNotifier.loading)
            const Center(child: CircularProgressIndicator())
          else if (teamNotifier.error != null)
            _ErrorState(error: teamNotifier.error!)
          else if (dimensions.isEmpty)
            const _EmptyState()
          else
            _Content(
              dimensions: dimensions,
              domains: domains,
              data: data,
            ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.dimensions,
    required this.domains,
    required this.data,
  });

  final List<Dimension> dimensions;
  final List<ApplicationDomain> domains;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final average = computeAverage(dimensions);
    final distribution = computeDistribution(dimensions, data.tiers);
    final insights = computeProfileInsights(
      dimensions,
      domains,
      data.tiers,
    );
    final styleLens = computeStyleLens(
      dimensions,
      tiers: data.tiers,
      maxScore: data.maxScore,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CapabilityProfileCard(
          dimensions: dimensions,
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.group_outlined,
            size: 48,
            color: DashboardTheme.subtle,
          ),
          const SizedBox(height: 16),
          Text(
            'No team insights available yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Team submissions from the SDLC Matrix tab will appear here once you and your teammates submit your matrices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthNotifier>();
    final teamNotifier = context.read<TeamNotifier>();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            'Unable to load team insights',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final token = auth.token;
              if (token != null) {
                teamNotifier.fetchTeamData(token, force: true);
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
