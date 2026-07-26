import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_notifier.dart';
import '../theme/dashboard_theme.dart';
import 'edit_panel.dart';
import 'header.dart';
import 'profile_tab.dart';
import 'sdlc_tab.dart';
import 'team_radar_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  bool _editing = false;
  int? _selectedDimensionId;
  int? _selectedDomainId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() {
      _editing = !_editing;
      if (!_editing) {
        _selectedDimensionId = null;
        _selectedDomainId = null;
      }
    });
  }

  void _selectDimension(int? id) {
    setState(() => _selectedDimensionId = id);
  }

  void _selectDomain(int? id) {
    setState(() => _selectedDomainId = id);
  }

  Widget _buildNarrowTabBar() {
    final labels = ['Team Capabilities', 'SDLC Application', 'Profile Insights'];
    final icons = [Icons.radar, Icons.grid_view, Icons.insights];
    final currentIndex = _tabController.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icons[currentIndex], size: 18, color: DashboardTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: currentIndex,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DashboardTheme.primary,
                ),
                items: List.generate(3, (i) {
                  return DropdownMenuItem<int>(
                    value: i,
                    child: Text(labels[i]),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    _tabController.animateTo(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;
    final width = MediaQuery.sizeOf(context).width;
    final stackEditPanel = width <= 1300;
    final useTabMenu = width <= 500;

    final tabContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          child: useTabMenu
              ? _buildNarrowTabBar()
              : TabBar(
                  isScrollable: true,
                  controller: _tabController,
                  labelColor: DashboardTheme.primary,
                  unselectedLabelColor: DashboardTheme.muted,
                  indicatorColor: DashboardTheme.primary,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, size: 18),
                          SizedBox(width: 8),
                          Text('Team Capabilities'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.grid_view, size: 18),
                          SizedBox(width: 8),
                          Text('SDLC Application'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insights, size: 18),
                          SizedBox(width: 8),
                          Text('Profile Insights'),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: TeamRadarTab(),
              ),
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: SDLCTab(
                  selectedDomainId: _selectedDomainId,
                  onSelectDomain: _selectDomain,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: ProfileTab(),
              ),
            ],
          ),
        ),
      ],
    );

    final header = Header(
      title: data.title,
      subtitle: data.subtitle,
      editing: _editing,
      onToggleEdit: _toggleEdit,
      onExport: notifier.exportJson,
      onImport: notifier.importJson,
      onReset: notifier.resetToDefaults,
    );

    final editPanel = EditPanel(
      fullWidth: stackEditPanel,
      selectedDimensionId: _selectedDimensionId,
      selectedDomainId: _selectedDomainId,
      onSelectDimension: (id) => _selectDimension(id),
      onSelectDomain: (id) => _selectDomain(id),
      onClose: _toggleEdit,
    );

    final body = stackEditPanel
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_editing) ...[
                editPanel,
                const SizedBox(height: 24),
              ],
              Expanded(child: tabContent),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_editing) ...[
                SizedBox(
                  width: 360,
                  child: editPanel,
                ),
                const SizedBox(width: 24),
              ],
              Expanded(child: tabContent),
            ],
          );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Padding(
          padding: EdgeInsets.all(width <= 600 ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 20),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}