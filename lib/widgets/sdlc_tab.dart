import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_notifier.dart';
import 'capability_application_matrix.dart';
import 'how_to_read_card.dart';

class SDLCTab extends StatelessWidget {
  const SDLCTab({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;

    final matrix = CapabilityApplicationMatrix(
      dimensions: data.dimensions,
      domains: data.applicationDomains,
      maxScore: data.maxScore,
      selectedDimensionId: null,
      selectedDomainId: null,
      onSelectDimension: null,
      onSelectDomain: null,
      onToggleCapabilityLink: notifier.toggleDomainCapability,
    );

    final applicationMatrixHowToRead = HowToReadCard(
      title: 'How to Read — Capability × Domain',
      text: data.applicationMatrixHowToRead,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          applicationMatrixHowToRead,
          const SizedBox(height: 20),
          matrix,
        ],
      ),
    );
  }
}