import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/individual_profile.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/team_notifier.dart';
import '../theme/dashboard_theme.dart';
import 'interactive_radar_chart.dart';

class TeamRadarTab extends StatefulWidget {
  const TeamRadarTab({super.key});

  @override
  State<TeamRadarTab> createState() => _TeamRadarTabState();
}

class _TeamRadarTabState extends State<TeamRadarTab> {
  int? _selectedDimensionId;
  int? _selectedMemberIndex;
  final _nameController = TextEditingController();
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

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
      selectedDimensionId: _selectedDimensionId,
      onSelectDimension: (id) {
        setState(() {
          _selectedDimensionId = _selectedDimensionId == id ? null : id;
        });
      },
      teamMembers: profile.members,
      teamMins: teamMins,
      teamMaxs: teamMaxs,
      highlightedMemberIndex: _selectedMemberIndex,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, profile),
          const SizedBox(height: 20),
          if (profile.members.isEmpty)
            _buildEmptyState(context, teamNotifier, data.dimensions)
          else
            _buildRadarSection(
              chart,
              sideBySide,
              width,
            ),
          const SizedBox(height: 20),
          _buildMemberManagement(context, teamNotifier, data.dimensions, width),
          const SizedBox(height: 20),
          _buildCsvSection(context, teamNotifier, data.dimensions),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic profile) {
    final selectedName = _selectedMemberIndex != null &&
            _selectedMemberIndex! < profile.members.length
        ? profile.members[_selectedMemberIndex!].name
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.members.isEmpty
              ? 'Team Radar'
              : selectedName != null
                  ? '$selectedName — Individual View'
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
              : profile.members.isEmpty
                  ? 'Add team members to see aggregate capability scores.'
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

  Widget _buildEmptyState(
    BuildContext context,
    TeamNotifier teamNotifier,
    List<dynamic> dimensions,
  ) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.group_add, size: 48, color: DashboardTheme.subtle),
          const SizedBox(height: 16),
          const Text(
            'Add team members to see aggregate capability scores',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 20),
          _buildAddMemberRow(context, teamNotifier),
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

  Widget _buildMemberManagement(
    BuildContext context,
    TeamNotifier teamNotifier,
    List<dynamic> dimensions,
    double width,
  ) {
    final profile = teamNotifier.profile;
    final narrow = width <= 700;

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
          _buildAddMemberRow(context, teamNotifier),
          const SizedBox(height: 16),
          if (profile.members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No members yet. Add a member above or import a CSV.',
                  style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
                ),
              ),
            )
          else
            ...List.generate(profile.members.length, (mi) {
              final member = profile.members[mi];
              final color = _memberColors[mi % _memberColors.length];
              final isSelected = _selectedMemberIndex == mi;
              return _MemberCard(
                member: member,
                index: mi,
                color: color,
                dimensions: dimensions,
                maxScore: 5,
                narrow: narrow,
                isSelected: isSelected,
                onToggle: () => _toggleMember(mi),
                onRemove: () {
                  if (_selectedMemberIndex == mi) {
                    _selectedMemberIndex = null;
                  }
                  teamNotifier.removeMember(mi);
                },
                onUpdateName: (name) => teamNotifier.updateMemberName(mi, name),
                onUpdateScore: (dimIdx, score) =>
                    teamNotifier.updateMemberScore(mi, dimIdx, score),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAddMemberRow(BuildContext context, TeamNotifier teamNotifier) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Member name',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: DashboardTheme.cardBorder),
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                teamNotifier.addMember(value.trim());
                _nameController.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty) {
              teamNotifier.addMember(_nameController.text.trim());
              _nameController.clear();
            }
          },
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add'),
          style: ElevatedButton.styleFrom(
            backgroundColor: DashboardTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCsvSection(
    BuildContext context,
    TeamNotifier teamNotifier,
    List<dynamic> dimensions,
  ) {
    final dimNames = dimensions.map((d) => d.name).cast<String>().toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import / Export',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.heading,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Export team scores as CSV or import from a CSV file. Format: Name, followed by one column per capability dimension.',
            style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _exportCsv(context, teamNotifier, dimNames),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _importCsv(context, teamNotifier, dimNames),
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Import CSV'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    TeamNotifier teamNotifier,
    List<String> dimNames,
  ) async {
    try {
      await teamNotifier.downloadCsv(dimNames);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export cancelled or failed: $e')),
        );
      }
    }
  }

  Future<void> _importCsv(
    BuildContext context,
    TeamNotifier teamNotifier,
    List<String> dimNames,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    final outcome = await teamNotifier.importCsv(
      bytes: bytes,
      dimensionNames: dimNames,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.success
                ? 'Imported ${teamNotifier.memberCount} members'
                : outcome.error ?? 'Import failed',
          ),
          backgroundColor:
              outcome.success ? DashboardTheme.primary : Colors.red,
        ),
      );
    }
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.index,
    required this.color,
    required this.dimensions,
    required this.maxScore,
    required this.narrow,
    required this.isSelected,
    required this.onToggle,
    required this.onRemove,
    required this.onUpdateName,
    required this.onUpdateScore,
  });

  final IndividualProfile member;
  final int index;
  final Color color;
  final List<dynamic> dimensions;
  final int maxScore;
  final bool narrow;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onUpdateName;
  final void Function(int dimIdx, double score) onUpdateScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(
                      Icons.remove_circle_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    controller: TextEditingController(text: member.name),
                    onChanged: onUpdateName,
                  ),
                  const SizedBox(height: 12),
                  if (narrow)
                    for (var i = 0; i < dimensions.length; i++)
                      _ScoreSlider(
                        dimensionName: '${i + 1}. ${dimensions[i].name}',
                        dimensionColor:
                            DashboardTheme.parseHex(dimensions[i].color),
                        score: i < member.scores.length
                            ? member.scores[i]
                            : 3.0,
                        maxScore: maxScore,
                        onChanged: (s) => onUpdateScore(i, s),
                      )
                  else
                    ..._buildScoreRows(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildScoreRows() {
    final rows = <Widget>[];
    final mid = (dimensions.length / 2).ceil();
    for (var row = 0; row < mid; row++) {
      final leftIdx = row;
      final rightIdx = row + mid;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: _ScoreSlider(
                  dimensionName: '${leftIdx + 1}. ${dimensions[leftIdx].name}',
                  dimensionColor: DashboardTheme.parseHex(
                    dimensions[leftIdx].color,
                  ),
                  score: leftIdx < member.scores.length
                      ? member.scores[leftIdx]
                      : 3.0,
                  maxScore: maxScore,
                  onChanged: (s) => onUpdateScore(leftIdx, s),
                ),
              ),
              const SizedBox(width: 16),
              if (rightIdx < dimensions.length)
                Expanded(
                  child: _ScoreSlider(
                    dimensionName:
                        '${rightIdx + 1}. ${dimensions[rightIdx].name}',
                    dimensionColor: DashboardTheme.parseHex(
                      dimensions[rightIdx].color,
                    ),
                    score: rightIdx < member.scores.length
                        ? member.scores[rightIdx]
                        : 3.0,
                    maxScore: maxScore,
                    onChanged: (s) => onUpdateScore(rightIdx, s),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

class _ScoreSlider extends StatelessWidget {
  const _ScoreSlider({
    required this.dimensionName,
    required this.dimensionColor,
    required this.score,
    required this.maxScore,
    required this.onChanged,
  });

  final String dimensionName;
  final Color dimensionColor;
  final double score;
  final int maxScore;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 8,
          height: 8,
          child: Container(
            decoration: BoxDecoration(
              color: dimensionColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 130,
          child: Text(
            dimensionName,
            style: const TextStyle(fontSize: 11, color: DashboardTheme.body),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Slider(
            value: score,
            min: 1,
            max: maxScore.toDouble(),
            divisions: (maxScore - 1) * 10,
            activeColor: dimensionColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
            ),
          ),
        ),
      ],
    );
  }
}