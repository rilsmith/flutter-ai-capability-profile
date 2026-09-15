import 'package:flutter/material.dart';

import '../models/application_domain.dart';
import '../models/dimension.dart';
import '../providers/team_notifier.dart';
import '../theme/dashboard_theme.dart';
import 'capability_definition_dialog.dart';

/// Read-only aggregate version of the AI × SDLC adoption matrix.
///
/// Mirrors the layout of [CapabilityApplicationMatrix] but instead of a single
/// person's links, each cell shows how many team members linked a capability
/// to a lifecycle domain. Cell color runs along a green→yellow→red heat ramp
/// scaled by the share of members.
class TeamCapabilityHeatmap extends StatelessWidget {
  const TeamCapabilityHeatmap({
    super.key,
    required this.dimensions,
    required this.domains,
    required this.linkCounts,
    required this.memberCount,
  });

  final List<Dimension> dimensions;
  final List<ApplicationDomain> domains;
  final TeamLinkCounts linkCounts;
  final int memberCount;

  static const _capabilityWidth = 180.0;
  static const _cellWidthMin = 34.0;
  static const _wideBreakpoint = 768.0;
  static const _horizontalHeaderBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('AI × SDLC Adoption Heatmap', style: DashboardTheme.cardHeading),
          const SizedBox(height: 6),
          Text(
            'Aggregated from $memberCount ${memberCount == 1 ? 'submission' : 'submissions'}. '
            'Cell color and number show how many members linked the capability to the domain.',
            style: const TextStyle(
              fontSize: 12,
              color: DashboardTheme.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              final horizontalHeaders =
                  constraints.maxWidth >= _horizontalHeaderBreakpoint;
              final headerHeight = horizontalHeaders ? 44.0 : 96.0;
              final gridWidth = constraints.maxWidth - _capabilityWidth;
              final cellWidth = isWide
                  ? (gridWidth / domains.length)
                      .clamp(_cellWidthMin, double.infinity)
                  : _cellWidthMin;

              final domainGrid = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DomainHeaderRow(
                    domains: domains,
                    cellWidth: cellWidth,
                    headerHeight: headerHeight,
                    horizontalLabels: horizontalHeaders,
                  ),
                  ...dimensions.map((dimension) {
                    return _HeatmapDataRow(
                      dimension: dimension,
                      domains: domains,
                      cellWidth: cellWidth,
                      linkCounts: linkCounts,
                      memberCount: memberCount,
                    );
                  }),
                ],
              );

              final matrix = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  _CapabilityColumn(
                    width: _capabilityWidth,
                    headerHeight: headerHeight,
                    dimensions: dimensions,
                  ),
                  if (isWide)
                    Expanded(child: domainGrid)
                  else
                    domainGrid,
                ],
              );

              if (isWide) {
                return matrix;
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: matrix,
              );
            },
          ),
          const SizedBox(height: 12),
          const _Legend(),
        ],
      ),
    );
  }
}

/// Discrete heat scale for adoption share [t] in [0, 1]; more is better:
/// red (few members) → light red → light green → green (everyone).
Color _heatColor(double t) {
  const red = Color(0xFFD93025);
  const lightRed = Color(0xFFF2A69B);
  const lightGreen = Color(0xFFA8D5A2);
  const green = Color(0xFF2E9E4F);
  final clamped = t.clamp(0.0, 1.0);
  if (clamped >= 1.0) return green;
  if (clamped >= 0.5) return lightGreen;
  if (clamped >= 0.25) return lightRed;
  return red;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget swatch(double t) => Container(
          width: 18,
          height: 12,
          decoration: BoxDecoration(
            color: _heatColor(t),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: DashboardTheme.cardBorder),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Fewer members',
          style: const TextStyle(fontSize: 11, color: DashboardTheme.muted),
        ),
        const SizedBox(width: 6),
        swatch(0.05),
        const SizedBox(width: 2),
        swatch(0.35),
        const SizedBox(width: 2),
        swatch(0.6),
        const SizedBox(width: 2),
        swatch(1.0),
        const SizedBox(width: 6),
        Text(
          'More members',
          style: const TextStyle(fontSize: 11, color: DashboardTheme.muted),
        ),
      ],
    );
  }
}

class _CapabilityColumn extends StatelessWidget {
  const _CapabilityColumn({
    required this.width,
    required this.headerHeight,
    required this.dimensions,
  });

  final double width;
  final double headerHeight;
  final List<Dimension> dimensions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: headerHeight),
          ...dimensions.map((dimension) {
            final color = DashboardTheme.parseHex(dimension.color);
            return SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dimension.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: DashboardTheme.body,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: DashboardTheme.muted,
                      ),
                      tooltip: 'Capability definition',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      onPressed: () => showCapabilityDefinitionDialog(
                        context,
                        dimension,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DomainHeaderRow extends StatelessWidget {
  const _DomainHeaderRow({
    required this.domains,
    required this.cellWidth,
    required this.headerHeight,
    required this.horizontalLabels,
  });

  final List<ApplicationDomain> domains;
  final double cellWidth;
  final double headerHeight;
  final bool horizontalLabels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: headerHeight,
      child: Row(
        children: domains.map((domain) {
          return SizedBox(
            width: cellWidth,
            child: horizontalLabels
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      domain.shortName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: domain.isNotApplicable
                            ? DashboardTheme.subtle
                            : DashboardTheme.body,
                      ),
                    ),
                  )
                : RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      domain.shortName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: domain.isNotApplicable
                            ? DashboardTheme.subtle
                            : DashboardTheme.body,
                      ),
                    ),
                  ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeatmapDataRow extends StatelessWidget {
  const _HeatmapDataRow({
    required this.dimension,
    required this.domains,
    required this.cellWidth,
    required this.linkCounts,
    required this.memberCount,
  });

  final Dimension dimension;
  final List<ApplicationDomain> domains;
  final double cellWidth;
  final TeamLinkCounts linkCounts;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: domains.map((domain) {
          final inScope = linkCounts.inScopeCount(domain.id);
          final count = linkCounts.linkCount(domain.id, dimension.id);

          return SizedBox(
            width: cellWidth,
            child: Center(
              child: inScope == 0
                  ? const _NaCell()
                  : Tooltip(
                      message: memberCount == 1
                          ? '$count of 1 member'
                          : '$count of $memberCount members',
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          // Discrete heat scale (see [_heatColor]); the
                          // per-dimension hue stays in the label dots. The
                          // count is in the tooltip rather than the cell.
                          color: count > 0
                              ? _heatColor(count / memberCount)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          border: count > 0
                              ? null
                              : Border.all(color: DashboardTheme.cardBorder),
                        ),
                      ),
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NaCell extends StatelessWidget {
  const _NaCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
