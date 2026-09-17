import 'package:flutter/material.dart';

import '../data/domain_help.dart';
import '../models/application_domain.dart';
import '../theme/dashboard_theme.dart';

Widget _sectionLabel(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: DashboardTheme.muted,
      ),
    );

Widget _bulletList(List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.fiber_manual_record, size: 5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: DashboardTheme.body,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ],
    );

/// Contextual help for an SDLC stage column: what kinds of activities fall
/// into it, with AI-specific examples and the adjacent-stage boundary.
void showDomainHelpDialog(BuildContext context, ApplicationDomain domain) {
  final help = domainHelp[domain.name];

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        domain.name,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (help == null) ...[
              const Text(
                'No guidance has been written for this stage yet.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: DashboardTheme.body,
                ),
              ),
            ] else ...[
              _sectionLabel('Definition'),
              const SizedBox(height: 4),
              Text(
                help.definition,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: DashboardTheme.body,
                ),
              ),
              const SizedBox(height: 14),
              _sectionLabel("You're here when you…"),
              const SizedBox(height: 4),
              _bulletList(help.activities),
              const SizedBox(height: 10),
              _sectionLabel('With AI'),
              const SizedBox(height: 4),
              _bulletList(help.aiExamples),
              const SizedBox(height: 14),
              _sectionLabel('Common mix-up'),
              const SizedBox(height: 4),
              Text(
                help.boundary,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: DashboardTheme.body,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
