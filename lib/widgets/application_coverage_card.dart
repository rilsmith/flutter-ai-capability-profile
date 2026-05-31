import 'package:flutter/material.dart';

import '../models/application_domain.dart';
import '../models/dimension.dart';
import '../models/tier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/application.dart';
import 'application_coverage_strip.dart';

class ApplicationCoverageCard extends StatelessWidget {
  const ApplicationCoverageCard({
    super.key,
    required this.domains,
    required this.dimensions,
    required this.tiers,
    this.selectedDomainId,
    this.onSelectDomain,
    this.onCycleInvolvement,
  });

  final List<ApplicationDomain> domains;
  final List<Dimension> dimensions;
  final TierGroup tiers;
  final int? selectedDomainId;
  final ValueChanged<int>? onSelectDomain;
  final ValueChanged<int>? onCycleInvolvement;

  @override
  Widget build(BuildContext context) {
    final breadth = computeApplicationBreadth(domains);
    final shape = profileShapeLabel(dimensions, domains, tiers);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Application Coverage', style: DashboardTheme.cardHeading),
              _Stats(breadth: breadth, shape: shape),
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
          const Text(
            'Click a bar to cycle agent use (Never → Occasional → Regular). Dashed border = involvement and capability links differ.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: DashboardTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: const [
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

class _Stats extends StatelessWidget {
  const _Stats({required this.breadth, required this.shape});

  final ApplicationBreadth breadth;
  final String shape;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatBlock(
          value: '${breadth.activeCount}/${breadth.inScopeCount}',
          label: 'domains with agent use',
        ),
        const SizedBox(width: 24),
        _StatBlock(value: shape, label: 'profile shape', compact: true),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    this.compact = false,
  });

  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: compact ? 14 : 22,
            fontWeight: FontWeight.w700,
            color: compact ? DashboardTheme.body : DashboardTheme.primary,
          ),
        ),
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
