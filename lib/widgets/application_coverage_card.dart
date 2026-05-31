import 'package:flutter/material.dart';

import '../models/application_domain.dart';
import '../theme/dashboard_theme.dart';
import '../utils/application.dart';
import 'application_coverage_strip.dart';

class ApplicationCoverageCard extends StatelessWidget {
  const ApplicationCoverageCard({
    super.key,
    required this.domains,
    this.selectedDomainId,
    this.onSelectDomain,
    this.onCycleInvolvement,
  });

  final List<ApplicationDomain> domains;
  final int? selectedDomainId;
  final ValueChanged<int>? onSelectDomain;
  final ValueChanged<int>? onCycleInvolvement;

  @override
  Widget build(BuildContext context) {
    final breadth = computeApplicationBreadth(domains);
    final stackHeader = MediaQuery.sizeOf(context).width <= 1100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stackHeader)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SDLC Coverage', style: DashboardTheme.cardHeading),
                const SizedBox(height: 12),
                _StatBlock(
                  value: '${breadth.activeCount}/${breadth.inScopeCount}',
                  label: 'domains with agent use',
                  alignStart: true,
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('SDLC Coverage', style: DashboardTheme.cardHeading),
                ),
                _StatBlock(
                  value: '${breadth.activeCount}/${breadth.inScopeCount}',
                  label: 'domains with agent use',
                ),
              ],
            ),
          const SizedBox(height: 20),
          ApplicationCoverageStrip(
            domains: domains,
            selectedDomainId: selectedDomainId,
            onSelectDomain: onSelectDomain,
            onCycleInvolvement: onCycleInvolvement,
          ),
          const SizedBox(height: 16),
          const Divider(color: DashboardTheme.divider, height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Click a bar to cycle agent use (Never → Occasional → Regular). Dashed border = involvement and capability links differ.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashboardTheme.primary,
                  ),
                ),
              ),
              _LegendItem(color: DashboardTheme.primary, label: 'Regular'),
              _LegendItem(
                color: DashboardTheme.primary,
                partial: true,
                label: 'Occasional',
              ),
              _LegendItem(
                color: Color(0xFFF9FAFB),
                label: 'Never',
              ),
              _LegendItem(
                color: Color(0xFFF3F4F6),
                hatched: true,
                label: 'Not applicable',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    this.alignStart = false,
  });

  final String value;
  final String label;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          value,
          textAlign: alignStart ? TextAlign.left : TextAlign.right,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.primary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: DashboardTheme.muted,
            letterSpacing: 0.44,
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.partial = false,
    this.hatched = false,
  });

  final Color color;
  final String label;
  final bool partial;
  final bool hatched;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: DashboardTheme.cardBorder),
            color: hatched ? const Color(0xFFF3F4F6) : color,
          ),
          foregroundDecoration: partial
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.45, 0.45],
                    colors: [color, const Color(0xFFF9FAFB)],
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: DashboardTheme.muted),
        ),
      ],
    );
  }
}
