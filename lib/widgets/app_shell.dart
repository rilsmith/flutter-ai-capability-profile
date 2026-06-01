import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'edit_panel.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.forPdfExport = false,
    this.pdfSegmentKeys,
    this.onExportPdf,
  });

  /// Dashboard-only layout for PDF snapshot (no edit panel, desktop width).
  final bool forPdfExport;
  final List<GlobalKey>? pdfSegmentKeys;
  final Future<void> Function()? onExportPdf;

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
    final stackEditPanel = !widget.forPdfExport && width <= 1300;

    final dashboard = DashboardScreen(
      editing: widget.forPdfExport ? false : _editing,
      forPdfExport: widget.forPdfExport,
      pdfSegmentKeys: widget.pdfSegmentKeys,
      selectedDimensionId: _selectedDimensionId,
      selectedDomainId: _selectedDomainId,
      onToggleEdit: _toggleEdit,
      onSelectDimension: _selectDimension,
      onSelectDomain: _selectDomain,
      onExportPdf: widget.onExportPdf,
    );

    final editPanel = EditPanel(
      fullWidth: stackEditPanel,
      selectedDimensionId: _selectedDimensionId,
      selectedDomainId: _selectedDomainId,
      onSelectDimension: (id) => _selectDimension(id),
      onSelectDomain: (id) => _selectDomain(id),
      onClose: _toggleEdit,
    );

    final Widget child;
    if (widget.forPdfExport) {
      child = dashboard;
    } else if (stackEditPanel) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_editing) ...[
            editPanel,
            const SizedBox(height: 24),
          ],
          dashboard,
        ],
      );
    } else {
      child = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editing) ...[
            editPanel,
            const SizedBox(width: 24),
          ],
          Expanded(child: dashboard),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1600),
        child: Padding(
          padding: EdgeInsets.all(width <= 600 ? 16 : 24),
          child: child,
        ),
      ),
    );
  }
}
