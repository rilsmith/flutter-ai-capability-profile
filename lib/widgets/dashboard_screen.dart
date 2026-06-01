import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../data/style_lens_config.dart';
import '../utils/application.dart';
import '../utils/compute.dart';
import '../utils/style_lens.dart';
import 'capability_profile_card.dart';
import 'application_coverage_card.dart';
import 'capability_application_matrix.dart';
import 'intro_card.dart';
import 'header.dart';
import 'how_to_read_card.dart';
import 'interactive_radar_chart.dart';
import 'profile_insights_card.dart';
import 'style_lens_panel.dart';

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

    void handleSelectDimension(int id) {
      onSelectDimension(selectedDimensionId == id ? null : id);
    }

    void handleSelectDomain(int id) {
      onSelectDomain(selectedDomainId == id ? null : id);
    }

    final capabilityProfile = CapabilityProfileCard(
      dimensions: data.dimensions,
      average: average,
      maxScore: data.maxScore,
      distribution: distribution,
      tiers: data.tiers,
      maturityScale: data.maturityScale,
      selectedDimensionId: selectedDimensionId,
      onSelectDimension: handleSelectDimension,
    );
    final styleLens = computeStyleLens(
      data.dimensions,
      tiers: data.tiers,
      maxScore: data.maxScore,
      selectedDimensionId: selectedDimensionId,
    );
    final chart = InteractiveRadarChart(
      dimensions: data.dimensions,
      maxScore: data.maxScore,
      editing: editing,
      selectedDimensionId: selectedDimensionId,
      onSelectDimension: handleSelectDimension,
      onUpdateScore: (id, score) =>
          notifier.patchDimension(id, score: score),
    );
    final styleLensPanel = StyleLensPanel(
      analysis: styleLens,
      config: styleLensConfig,
      maxScore: data.maxScore,
    );
    final applicationCoverage = ApplicationCoverageCard(
      domains: data.applicationDomains,
      selectedDomainId: selectedDomainId,
      onSelectDomain: handleSelectDomain,
      onCycleInvolvement: notifier.cycleDomainInvolvement,
    );
    final applicationCoverageHowToRead = HowToReadCard(
      title: 'How to Read — SDLC Coverage',
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
      onSelectDimension: handleSelectDimension,
      onSelectDomain: handleSelectDomain,
      onToggleCapabilityLink: notifier.toggleDomainCapability,
    );
    final profileInsights = ProfileInsightsCard(insights: insights);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = width <= 600 ? 40 : 80;
        final availableInnerWidth = width - padding;
        
        final sideBySide = width > 900;
        final chartHeight = width <= 600 ? 520.0 : width <= 900 ? 580.0 : 640.0;
        
        final columnWidth = sideBySide ? (availableInnerWidth - 24) * 0.6 : availableInnerWidth;
        final effectiveChartSize = math.min(chartHeight, columnWidth) * 0.94;

        final chartSection = sideBySide
            ? SizedBox(
                height: chartHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: SizedBox(
                          width: effectiveChartSize,
                          height: effectiveChartSize,
                          child: chart,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(child: styleLensPanel),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(
                      width: effectiveChartSize,
                      height: effectiveChartSize,
                      child: chart,
                    ),
                  ),
                  const SizedBox(height: 20),
                  styleLensPanel,
                ],
              );

        return Container(
          padding: EdgeInsets.fromLTRB(
            width <= 600 ? 20 : 40,
            36,
            width <= 600 ? 20 : 40,
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
                onImport: notifier.importJson,
                onReset: notifier.resetToDefaults,
              ),
              const SizedBox(height: 28),
              intro,
              if (data.intro.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
              ],
              capabilityHowToRead,
              const SizedBox(height: 20),
              chartSection,
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
          ),
        );
      },
    );
  }
}
