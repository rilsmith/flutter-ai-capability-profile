import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class IntroCard extends StatelessWidget {
  const IntroCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardTheme.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.65,
          color: DashboardTheme.body,
        ),
      ),
    );
  }
}
