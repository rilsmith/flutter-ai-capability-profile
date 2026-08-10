import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
  }
}
