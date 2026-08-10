import 'package:flutter/material.dart';

import '../models/application_domain.dart';
import '../theme/dashboard_theme.dart';
import '../utils/application.dart';
import '../utils/application_sync.dart';
import 'dart:math' as math;

class ApplicationCoverageStrip extends StatelessWidget {
  const ApplicationCoverageStrip({
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

  double _involvementFill(DomainInvolvement involvement) {
    switch (involvement) {
      case DomainInvolvement.regular:
        return 1;
      case DomainInvolvement.occasional:
        return 0.45;
      case DomainInvolvement.none:
        return 0;
    }
  }

  static const _barHeight = 72.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against zero or very small widths during initial layout
        if (constraints.maxWidth <= _gap * 2) {
          return const SizedBox.shrink();
        }

        final columns = constraints.maxWidth <= 700 ? 3 : 9;
        final itemWidth = math.max(0.0, (constraints.maxWidth - (columns - 1) * _gap) / columns);

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final domain in domains)
              SizedBox(
                width: itemWidth,
                child: _Segment(
                  domain: domain,
                  barHeight: _barHeight,
                  selected: selectedDomainId == domain.id,
                  onSelectDomain: onSelectDomain,
                  onCycleInvolvement: onCycleInvolvement,
                  involvementFill: _involvementFill,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.domain,
    required this.barHeight,
    required this.selected,
    required this.onSelectDomain,
    required this.onCycleInvolvement,
    required this.involvementFill,
  });

  final ApplicationDomain domain;
  final double barHeight;
  final bool selected;
  final ValueChanged<int>? onSelectDomain;
  final ValueChanged<int>? onCycleInvolvement;
  final double Function(DomainInvolvement) involvementFill;

  @override
  Widget build(BuildContext context) {
    final isNa = domain.isNotApplicable;
    final fill = involvementFill(domain.involvement);
    final divergent = domainHasInvolvementLinkDivergence(domain);
    final canCycle = onCycleInvolvement != null && !isNa;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? DashboardTheme.primaryLight : null,
        borderRadius: BorderRadius.circular(8),
        border: selected
            ? Border.all(color: const Color(0x332563EB))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            SizedBox(
              height: barHeight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canCycle
                      ? () => onCycleInvolvement!(domain.id)
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: divergent
                            ? const Color(0xFFCA8A04)
                            : DashboardTheme.cardBorder,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: isNa
                          ? const Color(0xFFF3F4F6)
                          : const Color(0xFFF9FAFB),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        if (!isNa)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: fill,
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: DashboardTheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSelectDomain == null
                    ? null
                    : () => onSelectDomain!(domain.id),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Text(
                        domain.shortName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: DashboardTheme.body,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isNa
                            ? 'N/A'
                            : onCycleInvolvement == null
                                ? involvementLabel(domain.involvement)
                                : '${involvementLabel(domain.involvement)} · Value ${signalLabel(domain.value)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: DashboardTheme.subtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
