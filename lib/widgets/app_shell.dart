import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'edit_panel.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _editing = false;
  int? _selectedDimensionId;
  int? _selectedDomainId;

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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final stackEditPanel = width <= 1300;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: stackEditPanel
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_editing) ...[
                      EditPanel(
                        fullWidth: true,
                        selectedDimensionId: _selectedDimensionId,
                        selectedDomainId: _selectedDomainId,
                        onSelectDimension: (id) => _selectDimension(id),
                        onSelectDomain: (id) => _selectDomain(id),
                      ),
                      const SizedBox(height: 24),
                    ],
                    DashboardScreen(
                      editing: _editing,
                      selectedDimensionId: _selectedDimensionId,
                      selectedDomainId: _selectedDomainId,
                      onToggleEdit: _toggleEdit,
                      onSelectDimension: _selectDimension,
                      onSelectDomain: _selectDomain,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_editing) ...[
                      EditPanel(
                        selectedDimensionId: _selectedDimensionId,
                        selectedDomainId: _selectedDomainId,
                        onSelectDimension: (id) => _selectDimension(id),
                        onSelectDomain: (id) => _selectDomain(id),
                      ),
                      const SizedBox(width: 24),
                    ],
                    Expanded(
                      child: DashboardScreen(
                        editing: _editing,
                        selectedDimensionId: _selectedDimensionId,
                        selectedDomainId: _selectedDomainId,
                        onToggleEdit: _toggleEdit,
                        onSelectDimension: _selectDimension,
                        onSelectDomain: _selectDomain,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
