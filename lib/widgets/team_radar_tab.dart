import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/individual_profile.dart';
import '../models/team_profile.dart';
import '../providers/auth_notifier.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/team_notifier.dart';
import '../theme/dashboard_theme.dart';
import 'application_coverage_card.dart';
import 'how_to_read_card.dart';
import 'interactive_radar_chart.dart';
import 'team_capability_heatmap.dart';

class TeamRadarTab extends StatefulWidget {
  const TeamRadarTab({super.key});

  @override
  State<TeamRadarTab> createState() => _TeamRadarTabState();
}

class _TeamRadarTabState extends State<TeamRadarTab>
    with AutomaticKeepAliveClientMixin<TeamRadarTab> {
  @override
  bool get wantKeepAlive => true;

  int? _selectedMemberIndex;

  final _memberColors = [
    const Color(0xFF7C3AED),
    const Color(0xFFDB2777),
    const Color(0xFF16A34A),
    const Color(0xFFEA580C),
    const Color(0xFF0D9488),
    const Color(0xFF4F46E5),
    const Color(0xFFDC2626),
    const Color(0xFFCA8A04),
    const Color(0xFF2563EB),
    const Color(0xFF9333EA),
  ];

  void _toggleMember(int index) {
    setState(() {
      _selectedMemberIndex = _selectedMemberIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dashNotifier = context.watch<DashboardNotifier>();
    final teamNotifier = context.watch<TeamNotifier>();
    final data = dashNotifier.data;
    final isOrg = teamNotifier.orgScope == TeamScope.org;
    final profile = isOrg ? teamNotifier.orgProfile : teamNotifier.profile;
    final aggregateCoverageDomains = isOrg
        ? teamNotifier.orgAggregateCoverageDomains
        : teamNotifier.aggregateCoverageDomains;
    final linkCounts = isOrg ? teamNotifier.orgLinkCounts : teamNotifier.linkCounts;
    final loading = isOrg ? teamNotifier.orgLoading : teamNotifier.loading;
    final error = isOrg ? teamNotifier.orgError : teamNotifier.error;
    final width = MediaQuery.sizeOf(context).width;
    final sideBySide = width > 1000;

    final teamMins = profile.mins;
    final teamMaxs = profile.maxs;
    final averages = profile.averages;

    final List<double> mainScores;
    if (_selectedMemberIndex != null &&
        _selectedMemberIndex! < profile.members.length) {
      mainScores = profile.members[_selectedMemberIndex!].scores;
    } else {
      mainScores = averages;
    }

    final dimensions = data.dimensions;
    final mainDimensions = dimensions
        .map((d) => d.copyWith(
              score: mainScores.isNotEmpty && d.id <= mainScores.length
                  ? mainScores[d.id - 1]
                  : d.score,
            ))
        .toList();

    final chart = InteractiveRadarChart(
      dimensions: mainDimensions,
      maxScore: data.maxScore,
      editing: false,
      selectedDimensionId: null,
      onSelectDimension: null,
      teamMembers: profile.members,
      teamMins: teamMins,
      teamMaxs: teamMaxs,
      highlightedMemberIndex: _selectedMemberIndex,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScopeToggle(context, teamNotifier),
          const SizedBox(height: 16),
          if (isOrg) ...[
            _buildIncludeSelfToggle(context, teamNotifier),
            const SizedBox(height: 16),
          ],
          const HowToReadCard(
            title: 'How to Read — SDLC Coverage',
            text:
                'SDLC Coverage is a read-only view of how the team uses agents across the software development lifecycle. '
                'The bars reflect the average involvement across the team’s latest submissions, not the current user’s local matrix. '
                'Update coverage in the SDLC Matrix tab and tap Submit to refresh this view.',
          ),
          const SizedBox(height: 20),
          ApplicationCoverageCard(
            domains: aggregateCoverageDomains,
            onCycleInvolvement: null,
            onSelectDomain: null,
          ),
          if (profile.members.isNotEmpty) ...[
            const SizedBox(height: 20),
            TeamCapabilityHeatmap(
              dimensions: dimensions,
              domains: aggregateCoverageDomains,
              linkCounts: linkCounts,
              memberCount: profile.members.length,
            ),
          ],
          const SizedBox(height: 20),
          _buildHeader(context, profile, isOrg: isOrg),
          const SizedBox(height: 20),
          if (teamNotifier.warnings.isNotEmpty) _buildWarnings(context, teamNotifier),
          if (teamNotifier.warnings.isNotEmpty) const SizedBox(height: 16),
          if (loading)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    isOrg
                        ? 'Loading your org — walking the reporting tree…'
                        : 'Loading team data…',
                    style: const TextStyle(
                      fontSize: 13,
                      color: DashboardTheme.muted,
                    ),
                  ),
                ],
              ),
            )
          else if (error != null)
            _buildErrorState(context, teamNotifier, isOrg: isOrg)
          else if (profile.members.isEmpty)
            _buildEmptyState(context, isOrg: isOrg)
          else
            _buildRadarSection(chart, sideBySide, width),
          if (profile.members.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMemberList(context, profile, isOrg: isOrg),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeToggle(BuildContext context, TeamNotifier teamNotifier) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: DashboardTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _ScopeButton(
              label: 'My Team',
              subtitle: 'Me and my peers',
              selected: teamNotifier.orgScope == TeamScope.team,
              onTap: () {
                setState(() => _selectedMemberIndex = null);
                teamNotifier.setOrgScope(TeamScope.team);
              },
            ),
          ),
          Expanded(
            child: _ScopeButton(
              label: 'My Org',
              subtitle: 'Me and my reports (direct + indirect)',
              selected: teamNotifier.orgScope == TeamScope.org,
              onTap: () {
                setState(() => _selectedMemberIndex = null);
                teamNotifier.setOrgScope(TeamScope.org);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludeSelfToggle(BuildContext context, TeamNotifier teamNotifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: DashboardTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Include my own submission',
              style: TextStyle(
                fontSize: 14,
                color: DashboardTheme.body,
              ),
            ),
          ),
          Switch(
            value: teamNotifier.orgIncludeSelf,
            onChanged: (value) {
              setState(() => _selectedMemberIndex = null);
              teamNotifier.setOrgIncludeSelf(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    TeamProfile profile, {
    required bool isOrg,
  }) {
    final selectedName = _selectedMemberIndex != null &&
            _selectedMemberIndex! < profile.members.length
        ? profile.members[_selectedMemberIndex!].name
        : null;
    final scopeLabel = isOrg ? 'Org' : 'Team';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedName != null
              ? '$selectedName — Individual View'
              : profile.members.isEmpty
                  ? '$scopeLabel Radar'
                  : '$scopeLabel Radar — ${profile.members.length} ${profile.members.length == 1 ? 'member' : 'members'}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.heading,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selectedName != null
              ? 'Showing $selectedName\'s scores. Click other member names to compare, or click again to return to $scopeLabel average.'
              : 'The polygon shows the $scopeLabel average. Click a member name to view their individual scores. The shaded band shows the min-max range; colored dots show each member on every axis.',
          style: const TextStyle(fontSize: 13, color: DashboardTheme.muted),
        ),
        if (profile.members.length > 1 && selectedName == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildLegendRow(profile.members),
          ),
      ],
    );
  }

  Widget _buildLegendRow(List<IndividualProfile> members) {
    final visible = members.take(10).toList();
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: List.generate(visible.length, (i) {
        final color = _memberColors[i % _memberColors.length];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              visible[i].name,
              style: const TextStyle(
                fontSize: 11,
                color: DashboardTheme.muted,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isOrg}) {
    final title = isOrg ? 'No org submissions yet' : 'No team submissions yet';
    final body = isOrg
        ? 'Org submissions from the SDLC Matrix tab will appear here once people in your reporting tree submit their matrices.'
        : 'Team submissions from the SDLC Matrix tab will appear here once you and your teammates submit your matrices.';
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.group_outlined, size: 48, color: DashboardTheme.subtle),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildWarnings(BuildContext context, TeamNotifier teamNotifier) {
    final warnings = teamNotifier.warnings;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Text(
                warnings.length == 1
                    ? '1 teammate submission could not be loaded'
                    : '${warnings.length} teammate submissions could not be loaded',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 2),
              child: Text(
                w,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    TeamNotifier teamNotifier, {
    required bool isOrg,
  }) {
    final auth = context.read<AuthNotifier>();
    final error = isOrg ? teamNotifier.orgError! : teamNotifier.error!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            isOrg ? 'Unable to load org data' : 'Unable to load team data',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final token = auth.token;
              if (token != null) {
                if (isOrg) {
                  teamNotifier.fetchOrgData(token, force: true);
                } else {
                  teamNotifier.fetchTeamData(token, force: true);
                }
              }
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarSection(
    InteractiveRadarChart chart,
    bool sideBySide,
    double width,
  ) {
    final chartHeight = width <= 600 ? 480.0 : width <= 900 ? 540.0 : 600.0;
    final columnWidth = sideBySide ? (width - 80) * 0.6 : width - 80;
    final effectiveChartSize = math.min(chartHeight, columnWidth) * 0.94;

    if (sideBySide) {
      return SizedBox(
        height: chartHeight,
        child: Center(
          child: SizedBox(
            width: effectiveChartSize,
            height: effectiveChartSize,
            child: chart,
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: effectiveChartSize,
        height: effectiveChartSize,
        child: chart,
      ),
    );
  }

  Widget _buildMemberList(
    BuildContext context,
    TeamProfile profile, {
    required bool isOrg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOrg ? 'Org Members' : 'Team Members',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.heading,
                ),
              ),
              if (_selectedMemberIndex != null)
                TextButton(
                  onPressed: () => setState(() => _selectedMemberIndex = null),
                  child: Text(
                    isOrg ? 'Show org average' : 'Show team average',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(profile.members.length, (mi) {
            final member = profile.members[mi];
            final color = _memberColors[mi % _memberColors.length];
            final isSelected = _selectedMemberIndex == mi;
            return InkWell(
              onTap: () => _toggleMember(mi),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? DashboardTheme.primaryLight
                      : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? DashboardTheme.primary
                        : const Color(0xFFF3F4F6),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? DashboardTheme.primary
                              : DashboardTheme.body,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.visibility,
                          size: 16,
                          color: DashboardTheme.primary,
                        ),
                      ),
                    Text(
                      member.scores.isEmpty
                          ? ''
                          : (member.scores.reduce((a, b) => a + b) /
                                  member.scores.length)
                              .toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DashboardTheme.primary,
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

class _ScopeButton extends StatelessWidget {
  const _ScopeButton({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? DashboardTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : DashboardTheme.body,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white70 : DashboardTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}