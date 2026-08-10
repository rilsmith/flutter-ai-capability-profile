import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_notifier.dart';
import '../providers/dashboard_notifier.dart';
import '../providers/team_notifier.dart';
import '../theme/dashboard_theme.dart';
import 'header.dart';
import 'profile_tab.dart';
import 'sdlc_tab.dart';
import 'team_radar_tab.dart';
import 'user_menu.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthNotifier>();
    final teamNotifier = context.read<TeamNotifier>();
    final token = auth.token;
    // Defer the fetch to avoid notifying listeners during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        teamNotifier.fetchTeamData(token);
      } else {
        teamNotifier.clear();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildNarrowTabBar() {
    final labels = ['SDLC Matrix', 'Team Capabilities', 'Profile Insights'];
    final icons = [Icons.grid_view, Icons.radar, Icons.insights];
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
                          Icon(Icons.grid_view, size: 18),
                          SizedBox(width: 8),
                          Text('SDLC Matrix'),
                        ],
                      ),
                    ),
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
            children: const [
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: SDLCTab(),
              ),
              Padding(
                padding: EdgeInsets.only(top: 20),
                child: TeamRadarTab(),
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

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Header(
            title: data.title,
            subtitle: data.subtitle,
          ),
        ),
        const SizedBox(width: 16),
        const UserMenu(),
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
              const SizedBox(height: 12),
              Expanded(child: tabContent),
            ],
          ),
        ),
      ),
    );
  }
}
