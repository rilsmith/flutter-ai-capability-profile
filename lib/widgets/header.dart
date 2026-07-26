import 'package:flutter/material.dart';

import '../theme/dashboard_theme.dart';

class Header extends StatelessWidget {
  const Header({
    super.key,
    required this.title,
    required this.subtitle,
    required this.editing,
    this.showActions = true,
    required this.onToggleEdit,
    required this.onExport,
    required this.onImport,
    required this.onReset,
  });

  final String title;
  final String subtitle;
  final bool editing;
  final bool showActions;
  final VoidCallback onToggleEdit;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width <= 600;

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.heading,
            letterSpacing: -0.52,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: DashboardTheme.muted,
          ),
        ),
      ],
    );

    final actionSection = PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') onToggleEdit();
        if (value == 'export') onExport();
        if (value == 'import') onImport();
        if (value == 'reset') onReset();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                editing ? Icons.check_circle : Icons.edit,
                size: 18,
                color: editing ? DashboardTheme.primary : DashboardTheme.body,
              ),
              const SizedBox(width: 12),
              Text(
                editing ? 'Done Editing' : 'Edit Dashboard',
                style: TextStyle(
                  color: editing ? DashboardTheme.primary : DashboardTheme.body,
                  fontWeight: editing ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download, size: 18, color: DashboardTheme.body),
              const SizedBox(width: 12),
              const Text('Export JSON'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload, size: 18, color: DashboardTheme.body),
              const SizedBox(width: 12),
              const Text('Import JSON'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              const Text('Restore Defaults', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: DashboardTheme.cardBorder),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_vert, size: 18, color: DashboardTheme.body),
            const SizedBox(width: 8),
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DashboardTheme.body,
              ),
            ),
          ],
        ),
      ),
    );

    if (!showActions) {
      return titleSection;
    }

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleSection,
          const SizedBox(height: 20),
          actionSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleSection),
        const SizedBox(width: 16),
        actionSection,
      ],
    );
  }
}
