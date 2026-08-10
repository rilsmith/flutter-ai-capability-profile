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

class TeamRadarTab extends StatefulWidget {
  const TeamRadarTab({super.key});

  @override
  State<TeamRadarTab> createState() => _TeamRadarTabState();
}

class _TeamRadarTabState extends State<TeamRadarTab> {
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
    final dashNotifier = context.watch<DashboardNotifier>();
    final teamNotifier = context.watch<TeamNotifier>();
    final data = dashNotifier.data;
    final profile = teamNotifier.profile;
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
          HowToReadCard(
            title: 'How to Read — SDLC Coverage',
            text: data.applicationHowToRead,
          ),
          const SizedBox(height: 20),
          ApplicationCoverageCard(
            domains: teamNotifier.aggregateCoverageDomains,
            onCycleInvolvement: null,
            onSelectDomain: null,
          ),
          const SizedBox(height: 20),
          _buildHeader(context, profile),
          const SizedBox(height: 20),
          if (teamNotifier.loading)
            const Center(child: CircularProgressIndicator())
          else if (teamNotifier.error != null)
            _buildErrorState(context, teamNotifier)
          else if (profile.members.isEmpty)
            _buildEmptyState(context)
          else
            _buildRadarSection(chart, sideBySide, width),
          if (profile.members.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMemberList(context, profile),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TeamProfile profile) {
    final selectedName = _selectedMemberIndex != null &&
            _selectedMemberIndex! < profile.members.length
        ? profile.members[_selectedMemberIndex!].name
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedName != null
              ? '$selectedName — Individual View'
              : profile.members.isEmpty
                  ? 'Team Radar'
                  : 'Team Radar — ${profile.members.length} ${profile.members.length == 1 ? 'member' : 'members'}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.heading,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selectedName != null
              ? 'Showing $selectedName\'s scores. Click other member names to compare, or click again to return to team average.'
              : 'The polygon shows the team average. Click a member name to view their individual scores. The shaded band shows the min-max range; colored dots show each member on every axis.',
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.group_outlined, size: 48, color: DashboardTheme.subtle),
          const SizedBox(height: 16),
          Text(
            'No team submissions yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Team submissions from the SDLC Matrix tab will appear here once you and your teammates submit your matrices.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, TeamNotifier teamNotifier) {
    final auth = context.read<AuthNotifier>();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            'Unable to load team data',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            teamNotifier.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final token = auth.token;
              if (token != null) {
                teamNotifier.fetchTeamData(token, force: true);
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

  Widget _buildMemberList(BuildContext context, TeamProfile profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Team Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.heading,
                ),
              ),
              if (_selectedMemberIndex != null)
                TextButton(
                  onPressed: () => setState(() => _selectedMemberIndex = null),
                  child: const Text(
                    'Show team average',
                    style: TextStyle(fontSize: 12),
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