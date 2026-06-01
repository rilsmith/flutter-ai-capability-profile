import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.title,
    required this.subtitle,
    required this.editing,
    required this.onToggleEdit,
    required this.onExport,
  });

  final String title;
  final String subtitle;
  final bool editing;
  final VoidCallback onToggleEdit;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width <= 600;

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.heading,
            letterSpacing: -0.52,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: DashboardTheme.muted,
          ),
        ),
      ],
    );

    final actionSection = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          onPressed: onExport,
          style: DashboardTheme.secondaryButton,
          child: const Text('Export JSON'),
        ),
        editing
            ? FilledButton(
                onPressed: onToggleEdit,
                style: DashboardTheme.primaryButton,
                child: const Text('Done Editing'),
              )
            : OutlinedButton(
                onPressed: onToggleEdit,
                style: DashboardTheme.secondaryButton,
                child: const Text('Edit Dashboard'),
              ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleSection,
          const SizedBox(height: 20),
          actionSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleSection),
        const SizedBox(width: 16),
        actionSection,
      ],
    );
  }
}
