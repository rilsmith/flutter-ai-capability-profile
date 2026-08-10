import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_notifier.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/team_notifier.dart';
import 'capability_application_matrix.dart';
import 'how_to_read_card.dart';

class SDLCTab extends StatelessWidget {
  const SDLCTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;

    final token = auth.token;
    final isAuthenticated = auth.isLoggedIn && token != null;

    final matrix = CapabilityApplicationMatrix(
      dimensions: data.dimensions,
      domains: data.applicationDomains,
      maxScore: data.maxScore,
      selectedDimensionId: null,
      selectedDomainId: null,
      onSelectDimension: null,
      onSelectDomain: null,
      onToggleCapabilityLink: notifier.toggleDomainCapability,
      isSubmitting: notifier.submitting,
      submitEnabled: isAuthenticated && !notifier.submitting,
      onSubmit: isAuthenticated ? () => _handleSubmit(context) : null,
      submitSuccess: notifier.submitSuccess,
      submitError: notifier.submitError,
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

  Future<void> _handleSubmit(BuildContext context) async {
    final auth = context.read<AuthNotifier>();
    final dashboard = context.read<DashboardNotifier>();
    final team = context.read<TeamNotifier>();
    final token = auth.token;
    if (token == null) return;

    await dashboard.submit(token);

    if (dashboard.submitSuccess != null) {
      team.fetchTeamData(token, force: true);
    }
  }
}