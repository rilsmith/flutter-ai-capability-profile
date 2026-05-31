import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class HowToReadCard extends StatelessWidget {
  const HowToReadCard({
    super.key,
    required this.text,
    this.title = 'How to Read This',
  });

  final String text;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DashboardTheme.cardHeading),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: DashboardTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: DashboardTheme.body,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
