import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/distribution.dart';
import '../providers/dashboard_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/application.dart';
import '../utils/compute.dart';
import 'capability_profile_card.dart';
import 'application_coverage_card.dart';
import 'capability_application_matrix.dart';
import 'intro_card.dart';
import 'header.dart';
import 'how_to_read_card.dart';
import 'interactive_radar_chart.dart';
import 'profile_insights_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.editing,
    required this.selectedDimensionId,
    required this.selectedDomainId,
    required this.onToggleEdit,
    required this.onSelectDimension,
    required this.onSelectDomain,
  });

  final bool editing;
  final int? selectedDimensionId;
  final int? selectedDomainId;
  final VoidCallback onToggleEdit;
  final ValueChanged<int?> onSelectDimension;
  final ValueChanged<int?> onSelectDomain;

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
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      padding: EdgeInsets.fromLTRB(
        width <= 700 ? 20 : 40,
        36,
        width <= 700 ? 20 : 40,
        32,
      ),
      decoration: DashboardTheme.dashboardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Header(
            title: data.title,
            subtitle: data.subtitle,
            editing: editing,
            onToggleEdit: onToggleEdit,
            onExport: notifier.exportJson,
          ),
          const SizedBox(height: 28),
          _MainGrid(
            editing: editing,
            selectedDimensionId: selectedDimensionId,
            selectedDomainId: selectedDomainId,
            onSelectDimension: onSelectDimension,
            onSelectDomain: onSelectDomain,
            average: average,
            distribution: distribution,
            insights: insights,
          ),
        ],
      ),
    );
  }
}

class _MainGrid extends StatelessWidget {
  const _MainGrid({
    required this.editing,
    required this.selectedDimensionId,
    required this.selectedDomainId,
    required this.onSelectDimension,
    required this.onSelectDomain,
    required this.average,
    required this.distribution,
    required this.insights,
  });

  final bool editing;
  final int? selectedDimensionId;
  final int? selectedDomainId;
  final ValueChanged<int?> onSelectDimension;
  final ValueChanged<int?> onSelectDomain;
  final double average;
  final Distribution distribution;
  final List<String> insights;

  void _handleSelectDimension(int id) {
    onSelectDimension(selectedDimensionId == id ? null : id);
  }

  void _handleSelectDomain(int id) {
    onSelectDomain(selectedDomainId == id ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;
    final width = MediaQuery.sizeOf(context).width;

    final capabilityProfile = CapabilityProfileCard(
      dimensions: data.dimensions,
      average: average,
      maxScore: data.maxScore,
      distribution: distribution,
      tiers: data.tiers,
      maturityScale: data.maturityScale,
      selectedDimensionId: selectedDimensionId,
      onSelectDimension: _handleSelectDimension,
    );
    final chart = Center(
      child: InteractiveRadarChart(
        dimensions: data.dimensions,
        maxScore: data.maxScore,
        editing: editing,
        selectedDimensionId: selectedDimensionId,
        onSelectDimension: _handleSelectDimension,
        onUpdateScore: (id, score) =>
            notifier.patchDimension(id, score: score),
      ),
    );
    final applicationCoverage = ApplicationCoverageCard(
      domains: data.applicationDomains,
      dimensions: data.dimensions,
      tiers: data.tiers,
      selectedDomainId: selectedDomainId,
      onSelectDomain: _handleSelectDomain,
      onCycleInvolvement: notifier.cycleDomainInvolvement,
    );
    final applicationCoverageHowToRead = HowToReadCard(
      title: 'How to Read — Application Coverage',
      text: data.applicationHowToRead,
    );
    final applicationMatrixHowToRead = HowToReadCard(
      title: 'How to Read — Capability × Domain',
      text: data.applicationMatrixHowToRead,
    );
    final capabilityHowToRead = HowToReadCard(text: data.howToRead);
    final intro = IntroCard(text: data.intro);
    final matrix = CapabilityApplicationMatrix(
      dimensions: data.dimensions,
      domains: data.applicationDomains,
      selectedDimensionId: selectedDimensionId,
      selectedDomainId: selectedDomainId,
      onSelectDimension: _handleSelectDimension,
      onSelectDomain: _handleSelectDomain,
      onToggleCapabilityLink: notifier.toggleDomainCapability,
    );
    final profileInsights = ProfileInsightsCard(insights: insights);

    final chartHeight = width <= 700 ? 420.0 : width <= 1100 ? 480.0 : 520.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        if (data.intro.trim().isNotEmpty) const SizedBox(height: 20),
        capabilityHowToRead,
        const SizedBox(height: 20),
        SizedBox(height: chartHeight, child: chart),
        const SizedBox(height: 20),
        capabilityProfile,
        const SizedBox(height: 20),
        applicationCoverageHowToRead,
        const SizedBox(height: 20),
        applicationCoverage,
        const SizedBox(height: 20),
        applicationMatrixHowToRead,
        const SizedBox(height: 20),
        matrix,
        const SizedBox(height: 20),
        profileInsights,
      ],
    );
  }
}
