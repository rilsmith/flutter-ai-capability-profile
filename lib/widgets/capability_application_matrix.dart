import 'package:flutter/material.dart';

import '../models/application_domain.dart';
import '../models/dimension.dart';
import '../theme/dashboard_theme.dart';
import '../utils/application.dart';
import 'capability_definition_dialog.dart';

class CapabilityApplicationMatrix extends StatelessWidget {
  const CapabilityApplicationMatrix({
    super.key,
    required this.dimensions,
    required this.domains,
    required this.maxScore,
    this.selectedDimensionId,
    this.selectedDomainId,
    this.onSelectDimension,
    this.onSelectDomain,
    this.onToggleCapabilityLink,
  });

  final List<Dimension> dimensions;
  final List<ApplicationDomain> domains;
  final int maxScore;
  final int? selectedDimensionId;
  final int? selectedDomainId;
  final ValueChanged<int>? onSelectDimension;
  final ValueChanged<int>? onSelectDomain;
  final void Function(int domainId, int capabilityId)? onToggleCapabilityLink;

  static const _capabilityWidth = 180.0;
  static const _cellWidthMin = 34.0;
  static const _reachWidth = 44.0;
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
          Text('Capability × Domain Links', style: DashboardTheme.cardHeading),
          const SizedBox(height: 6),
          const Text(
            'Tap ⓘ beside a capability for its definition. Tap cells to toggle links.',
            style: TextStyle(fontSize: 12, color: DashboardTheme.muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= _wideBreakpoint;
              final horizontalHeaders =
                  constraints.maxWidth >= _horizontalHeaderBreakpoint;
              final headerHeight = horizontalHeaders ? 44.0 : 96.0;
              final gridWidth =
                  constraints.maxWidth - _capabilityWidth - _reachWidth;
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
                    selectedDomainId: selectedDomainId,
                    onSelectDomain: onSelectDomain,
                  ),
                  ...dimensions.map((dimension) {
                    final rowSelected = selectedDimensionId == dimension.id;
                    final color = DashboardTheme.parseHex(dimension.color);
                    return _MatrixDataRow(
                      dimension: dimension,
                      domains: domains,
                      cellWidth: cellWidth,
                      color: color,
                      rowSelected: rowSelected,
                      selectedDomainId: selectedDomainId,
                      onToggleCapabilityLink: onToggleCapabilityLink,
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
                    maxScore: maxScore,
                    selectedDimensionId: selectedDimensionId,
                    onSelectDimension: onSelectDimension,
                  ),
                  if (isWide)
                    Expanded(child: domainGrid)
                  else
                    domainGrid,
                  _ReachColumn(
                    width: _reachWidth,
                    headerHeight: headerHeight,
                    dimensions: dimensions,
                    domains: domains,
                    selectedDimensionId: selectedDimensionId,
                  ),
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
        ],
      ),
    );
  }
}

class _CapabilityColumn extends StatelessWidget {
  const _CapabilityColumn({
    required this.width,
    required this.headerHeight,
    required this.dimensions,
    required this.maxScore,
    required this.selectedDimensionId,
    required this.onSelectDimension,
  });

  final double width;
  final double headerHeight;
  final List<Dimension> dimensions;
  final int maxScore;
  final int? selectedDimensionId;
  final ValueChanged<int>? onSelectDimension;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: headerHeight),
          ...dimensions.map((dimension) {
            final selected = selectedDimensionId == dimension.id;
            final color = DashboardTheme.parseHex(dimension.color);
            return SizedBox(
              height: 40,
              child: Material(
                color: selected ? DashboardTheme.primaryLight : Colors.transparent,
                child: InkWell(
                  onTap: onSelectDimension == null
                      ? null
                      : () => onSelectDimension!(dimension.id),
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
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? DashboardTheme.primary
                                  : DashboardTheme.body,
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
                            maxScore: maxScore,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    required this.selectedDomainId,
    required this.onSelectDomain,
  });

  final List<ApplicationDomain> domains;
  final double cellWidth;
  final double headerHeight;
  final bool horizontalLabels;
  final int? selectedDomainId;
  final ValueChanged<int>? onSelectDomain;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: headerHeight,
      child: Row(
        children: domains.map((domain) {
          final selected = selectedDomainId == domain.id;
          return SizedBox(
            width: cellWidth,
            child: InkWell(
              onTap: onSelectDomain == null
                  ? null
                  : () => onSelectDomain!(domain.id),
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
                              : selected
                                  ? DashboardTheme.primary
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
                              : selected
                                  ? DashboardTheme.primary
                                  : DashboardTheme.body,
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

class _MatrixDataRow extends StatelessWidget {
  const _MatrixDataRow({
    required this.dimension,
    required this.domains,
    required this.cellWidth,
    required this.color,
    required this.rowSelected,
    required this.selectedDomainId,
    required this.onToggleCapabilityLink,
  });

  final Dimension dimension;
  final List<ApplicationDomain> domains;
  final double cellWidth;
  final Color color;
  final bool rowSelected;
  final int? selectedDomainId;
  final void Function(int domainId, int capabilityId)? onToggleCapabilityLink;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: domains.map((domain) {
          final isNa = domain.isNotApplicable;
          final linked = isCapabilityLinked(domain, dimension.id);
          final colSelected = selectedDomainId == domain.id;
          final canToggle = onToggleCapabilityLink != null && !isNa;

          return Container(
            width: cellWidth,
            color: colSelected
                ? DashboardTheme.primaryLight.withOpacity(0.65)
                : rowSelected
                    ? DashboardTheme.primaryLight.withOpacity(0.35)
                    : null,
            child: Center(
              child: isNa
                  ? const _NaCell()
                  : InkWell(
                      onTap: canToggle
                          ? () => onToggleCapabilityLink!(
                                domain.id,
                                dimension.id,
                              )
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Center(
                          child: linked
                              ? Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                              : Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: DashboardTheme.cardBorder,
                                    ),
                                  ),
                                ),
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

class _ReachColumn extends StatelessWidget {
  const _ReachColumn({
    required this.width,
    required this.headerHeight,
    required this.dimensions,
    required this.domains,
    required this.selectedDimensionId,
  });

  final double width;
  final double headerHeight;
  final List<Dimension> dimensions;
  final List<ApplicationDomain> domains;
  final int? selectedDimensionId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: headerHeight,
            child: const Center(
              child: Text(
                'Reach',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: DashboardTheme.muted,
                ),
              ),
            ),
          ),
          ...dimensions.map((dimension) {
            final selected = selectedDimensionId == dimension.id;
            final reach = linkedDomainCount(dimension.id, domains);
            return SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  '$reach',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? DashboardTheme.primary
                        : DashboardTheme.muted,
                  ),
                ),
              ),
            );
          }),
        ],
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
