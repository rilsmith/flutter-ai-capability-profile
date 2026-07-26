import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_notifier.dart';
import '../theme/dashboard_theme.dart';
import 'application_coverage_card.dart';
import 'capability_application_matrix.dart';
import 'how_to_read_card.dart';
import 'new_sdlc_flow_card.dart';

class SDLCTab extends StatelessWidget {
  const SDLCTab({
    super.key,
    required this.selectedDomainId,
    required this.onSelectDomain,
  });

  final int? selectedDomainId;
  final ValueChanged<int?> onSelectDomain;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;

    final applicationCoverage = ApplicationCoverageCard(
      domains: data.applicationDomains,
      selectedDomainId: selectedDomainId,
      onSelectDomain: onSelectDomain,
      onCycleInvolvement: notifier.cycleDomainInvolvement,
    );

    final matrix = CapabilityApplicationMatrix(
      dimensions: data.dimensions,
      domains: data.applicationDomains,
      maxScore: data.maxScore,
      selectedDimensionId: null,
      selectedDomainId: selectedDomainId,
      onSelectDimension: (_) {},
      onSelectDomain: onSelectDomain,
      onToggleCapabilityLink: notifier.toggleDomainCapability,
    );

    final applicationCoverageHowToRead = HowToReadCard(
      title: 'How to Read — SDLC Coverage',
      text: data.applicationHowToRead,
    );

    final applicationMatrixHowToRead = HowToReadCard(
      title: 'How to Read — Capability × Domain',
      text: data.applicationMatrixHowToRead,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SDLC Application',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'How the harness and agentic practices transform each phase of the software development lifecycle.',
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 20),
          applicationCoverageHowToRead,
          const SizedBox(height: 20),
          applicationCoverage,
          const SizedBox(height: 20),
          applicationMatrixHowToRead,
          const SizedBox(height: 20),
          matrix,
          const SizedBox(height: 20),
          const NewSDLCFlowCard(),
        ],
      ),
    );
  }
}