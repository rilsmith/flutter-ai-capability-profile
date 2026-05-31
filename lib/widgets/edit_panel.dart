import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/application_domain.dart';
import '../models/dashboard_data.dart';
import '../models/dimension.dart';
import '../providers/dashboard_notifier.dart';
import '../theme/dashboard_theme.dart';
import '../utils/compute.dart';

class EditPanel extends StatefulWidget {
  const EditPanel({
    super.key,
    required this.selectedDimensionId,
    required this.selectedDomainId,
    required this.onSelectDimension,
    required this.onSelectDomain,
    this.fullWidth = false,
  });

  final int? selectedDimensionId;
  final int? selectedDomainId;
  final ValueChanged<int> onSelectDimension;
  final ValueChanged<int> onSelectDomain;
  final bool fullWidth;

  @override
  State<EditPanel> createState() => _EditPanelState();
}

class _EditPanelState extends State<EditPanel> {
  final _scrollController = ScrollController();
  final _dimensionKeys = <int, GlobalKey>{};
  final _domainKeys = <int, GlobalKey>{};
  late TextEditingController _titleController;
  late TextEditingController _subtitleController;
  late TextEditingController _introController;
  late TextEditingController _howToReadController;
  late TextEditingController _applicationHowToReadController;
  late TextEditingController _applicationMatrixHowToReadController;
  int _dataRevision = 0;

  @override
  void initState() {
    super.initState();
    final data = context.read<DashboardNotifier>().data;
    _titleController = TextEditingController(text: data.title);
    _subtitleController = TextEditingController(text: data.subtitle);
    _introController = TextEditingController(text: data.intro);
    _howToReadController = TextEditingController(text: data.howToRead);
    _applicationHowToReadController =
        TextEditingController(text: data.applicationHowToRead);
    _applicationMatrixHowToReadController =
        TextEditingController(text: data.applicationMatrixHowToRead);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _introController.dispose();
    _howToReadController.dispose();
    _applicationHowToReadController.dispose();
    _applicationMatrixHowToReadController.dispose();
    super.dispose();
  }

  void _syncHeaderControllers(DashboardData data) {
    if (_titleController.text != data.title) {
      _titleController.text = data.title;
    }
    if (_subtitleController.text != data.subtitle) {
      _subtitleController.text = data.subtitle;
    }
    if (_introController.text != data.intro) {
      _introController.text = data.intro;
    }
    if (_howToReadController.text != data.howToRead) {
      _howToReadController.text = data.howToRead;
    }
    if (_applicationHowToReadController.text != data.applicationHowToRead) {
      _applicationHowToReadController.text = data.applicationHowToRead;
    }
    if (_applicationMatrixHowToReadController.text !=
        data.applicationMatrixHowToRead) {
      _applicationMatrixHowToReadController.text =
          data.applicationMatrixHowToRead;
    }
  }

  @override
  void didUpdateWidget(covariant EditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDimensionId != null &&
        widget.selectedDimensionId != oldWidget.selectedDimensionId) {
      _scrollToSelectedDimension();
    }
    if (widget.selectedDomainId != null &&
        widget.selectedDomainId != oldWidget.selectedDomainId) {
      _scrollToSelectedDomain();
    }
  }

  void _scrollToSelectedDimension() {
    final id = widget.selectedDimensionId;
    if (id == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _dimensionKeys[id];
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _scrollToSelectedDomain() {
    final id = widget.selectedDomainId;
    if (id == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _domainKeys[id];
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<DashboardNotifier>();
    final data = notifier.data;
    final revision = Object.hash(
      data.title,
      data.subtitle,
      data.intro,
      data.howToRead,
      data.applicationHowToRead,
      data.applicationMatrixHowToRead,
      data.dimensions.map((d) => Object.hash(
            d.id,
            d.name,
            d.score,
            d.color,
            d.descriptor,
          )),
    );
    if (revision != _dataRevision) {
      _dataRevision = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncHeaderControllers(data);
      });
    }

    return Container(
      width: widget.fullWidth ? double.infinity : 360,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height - 48,
      ),
      decoration: DashboardTheme.dashboardDecoration(),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.heading,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Changes save automatically. Click a chart label to select a dimension, or drag its point to adjust the score.',
                style: TextStyle(fontSize: 13, color: DashboardTheme.muted),
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Header',
                children: [
                  _Field(
                    label: 'Title',
                    child: TextField(
                      controller: _titleController,
                      onChanged: notifier.updateTitle,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  _Field(
                    label: 'Subtitle',
                    child: TextField(
                      controller: _subtitleController,
                      onChanged: notifier.updateSubtitle,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  _Field(
                    label: 'Intro',
                    child: TextField(
                      controller: _introController,
                      onChanged: notifier.updateIntro,
                      maxLines: 5,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  _Field(
                    label: 'How to Read — Capabilities',
                    child: TextField(
                      controller: _howToReadController,
                      onChanged: notifier.updateHowToRead,
                      maxLines: 3,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  _Field(
                    label: 'How to Read — Application Coverage',
                    child: TextField(
                      controller: _applicationHowToReadController,
                      onChanged: notifier.updateApplicationHowToRead,
                      maxLines: 3,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  _Field(
                    label: 'How to Read — Capability × Domain',
                    child: TextField(
                      controller: _applicationMatrixHowToReadController,
                      onChanged: notifier.updateApplicationMatrixHowToRead,
                      maxLines: 3,
                      decoration: _inputDecoration(),
                    ),
                  ),
                ],
              ),
              _Section(
                title: 'Dimensions',
                children: [
                  for (final dimension in data.dimensions)
                    _DimensionEditor(
                      key: _dimensionKeys.putIfAbsent(
                        dimension.id,
                        GlobalKey.new,
                      ),
                      dimension: dimension,
                      maxScore: data.maxScore,
                      selected: widget.selectedDimensionId == dimension.id,
                      onSelect: () => widget.onSelectDimension(dimension.id),
                      onUpdate: (patch) => notifier.patchDimension(
                        dimension.id,
                        name: patch.name,
                        score: patch.score,
                        color: patch.color,
                        descriptor: patch.descriptor,
                      ),
                    ),
                ],
              ),
              _Section(
                title: 'Application Domains',
                children: [
                  for (final domain in data.applicationDomains)
                    _ApplicationDomainEditor(
                      key: _domainKeys.putIfAbsent(domain.id, GlobalKey.new),
                      domain: domain,
                      dimensions: data.dimensions,
                      selected: widget.selectedDomainId == domain.id,
                      onSelect: () => widget.onSelectDomain(domain.id),
                      onUpdate: (patch) => notifier.patchApplicationDomain(
                        domain.id,
                        name: patch.name,
                        shortName: patch.shortName,
                        applicability: patch.applicability,
                        involvement: patch.involvement,
                        value: patch.value,
                        confidence: patch.confidence,
                        capabilityIds: patch.capabilityIds,
                      ),
                    ),
                ],
              ),
              const Divider(color: DashboardTheme.cardBorder),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: notifier.resetToDefaults,
                    style: DashboardTheme.secondaryButton,
                    child: const Text('Reset to Defaults'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final success = await notifier.importJson();
                      if (!context.mounted) return;
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not import file. Please choose a valid JSON export.',
                            ),
                          ),
                        );
                      }
                    },
                    style: DashboardTheme.secondaryButton,
                    child: const Text('Import JSON'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.primary),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DashboardTheme.cardHeading),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: DashboardTheme.body,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _DimensionPatch {
  const _DimensionPatch({
    this.name,
    this.score,
    this.color,
    this.descriptor,
  });

  final String? name;
  final double? score;
  final String? color;
  final String? descriptor;
}

class _DimensionEditor extends StatefulWidget {
  const _DimensionEditor({
    super.key,
    required this.dimension,
    required this.maxScore,
    required this.selected,
    required this.onSelect,
    required this.onUpdate,
  });

  final Dimension dimension;
  final int maxScore;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(_DimensionPatch patch) onUpdate;

  @override
  State<_DimensionEditor> createState() => _DimensionEditorState();
}

class _DimensionEditorState extends State<_DimensionEditor> {
  late TextEditingController _nameController;
  late TextEditingController _descriptorController;
  late TextEditingController _scoreController;
  late TextEditingController _colorController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dimension.name);
    _descriptorController =
        TextEditingController(text: widget.dimension.descriptor);
    _scoreController =
        TextEditingController(text: widget.dimension.score.toString());
    _colorController = TextEditingController(text: widget.dimension.color);
  }

  @override
  void didUpdateWidget(covariant _DimensionEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dimension.name != widget.dimension.name) {
      _nameController.text = widget.dimension.name;
    }
    if (oldWidget.dimension.descriptor != widget.dimension.descriptor) {
      _descriptorController.text = widget.dimension.descriptor;
    }
    if (oldWidget.dimension.score != widget.dimension.score) {
      _scoreController.text = widget.dimension.score.toString();
    }
    if (oldWidget.dimension.color != widget.dimension.color) {
      _colorController.text = widget.dimension.color;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptorController.dispose();
    _scoreController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = DashboardTheme.parseHex(widget.dimension.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: widget.selected ? DashboardTheme.primaryLight : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected
                    ? DashboardTheme.primary
                    : const Color(0xFFF3F4F6),
              ),
              boxShadow: widget.selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1F2563EB),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dimension ${widget.dimension.id}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DashboardTheme.body,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Field(
                  label: 'Name',
                  child: TextField(
                    controller: _nameController,
                    onChanged: (value) =>
                        widget.onUpdate(_DimensionPatch(name: value)),
                    decoration: _fieldDecoration(),
                  ),
                ),
                _Field(
                  label: 'Descriptor',
                  child: TextField(
                    controller: _descriptorController,
                    onChanged: (value) =>
                        widget.onUpdate(_DimensionPatch(descriptor: value)),
                    maxLines: 2,
                    decoration: _fieldDecoration(),
                  ),
                ),
                _Field(
                  label: 'Score (1–${widget.maxScore})',
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: widget.dimension.score,
                          min: 1,
                          max: widget.maxScore.toDouble(),
                          divisions: (widget.maxScore - 1) * 10,
                          onChanged: (value) {
                            final score =
                                clampScore(value, widget.maxScore);
                            _scoreController.text = score.toString();
                            widget.onUpdate(_DimensionPatch(score: score));
                          },
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _scoreController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed == null) return;
                            widget.onUpdate(
                              _DimensionPatch(
                                score: clampScore(parsed, widget.maxScore),
                              ),
                            );
                          },
                          decoration: _fieldDecoration(),
                        ),
                      ),
                    ],
                  ),
                ),
                _Field(
                  label: 'Accent color',
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DashboardTheme.cardBorder),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _colorController,
                          onChanged: (value) {
                            if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                              widget.onUpdate(_DimensionPatch(color: value));
                            }
                          },
                          decoration: _fieldDecoration(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.cardBorder),
      ),
    );
  }
}

class _ApplicationDomainPatch {
  const _ApplicationDomainPatch({
    this.name,
    this.shortName,
    this.applicability,
    this.involvement,
    this.value,
    this.confidence,
    this.capabilityIds,
  });

  final String? name;
  final String? shortName;
  final DomainApplicability? applicability;
  final DomainInvolvement? involvement;
  final DomainSignal? value;
  final DomainSignal? confidence;
  final List<int>? capabilityIds;
}

class _ApplicationDomainEditor extends StatefulWidget {
  const _ApplicationDomainEditor({
    super.key,
    required this.domain,
    required this.dimensions,
    required this.selected,
    required this.onSelect,
    required this.onUpdate,
  });

  final ApplicationDomain domain;
  final List<Dimension> dimensions;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(_ApplicationDomainPatch patch) onUpdate;

  @override
  State<_ApplicationDomainEditor> createState() =>
      _ApplicationDomainEditorState();
}

class _ApplicationDomainEditorState extends State<_ApplicationDomainEditor> {
  late TextEditingController _nameController;
  late TextEditingController _shortNameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.domain.name);
    _shortNameController = TextEditingController(text: widget.domain.shortName);
  }

  @override
  void didUpdateWidget(covariant _ApplicationDomainEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domain.name != widget.domain.name) {
      _nameController.text = widget.domain.name;
    }
    if (oldWidget.domain.shortName != widget.domain.shortName) {
      _shortNameController.text = widget.domain.shortName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortNameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardTheme.cardBorder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.domain.isNotApplicable;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: widget.selected ? DashboardTheme.primaryLight : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.onSelect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.selected
                    ? DashboardTheme.primary
                    : const Color(0xFFF3F4F6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Domain ${widget.domain.id}: ${widget.domain.shortName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.body,
                  ),
                ),
                const SizedBox(height: 10),
                _Field(
                  label: 'Name',
                  child: TextField(
                    controller: _nameController,
                    onChanged: (value) =>
                        widget.onUpdate(_ApplicationDomainPatch(name: value)),
                    decoration: _fieldDecoration(),
                  ),
                ),
                _Field(
                  label: 'Short label',
                  child: TextField(
                    controller: _shortNameController,
                    onChanged: (value) => widget.onUpdate(
                      _ApplicationDomainPatch(shortName: value),
                    ),
                    decoration: _fieldDecoration(),
                  ),
                ),
                _Field(
                  label: 'Applicability',
                  child: DropdownButtonFormField<DomainApplicability>(
                    value: widget.domain.applicability,
                    decoration: _fieldDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: DomainApplicability.inScope,
                        child: Text('In scope (part of my role)'),
                      ),
                      DropdownMenuItem(
                        value: DomainApplicability.notApplicable,
                        child: Text('Not applicable (outside my role)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      widget.onUpdate(
                        _ApplicationDomainPatch(applicability: value),
                      );
                    },
                  ),
                ),
                const Text(
                  'N/A excludes this domain from breadth counts and disables inline editing.',
                  style: TextStyle(fontSize: 11, color: DashboardTheme.subtle),
                ),
                const SizedBox(height: 8),
                _Field(
                  label: 'Agent involvement',
                  child: DropdownButtonFormField<DomainInvolvement>(
                    value: widget.domain.involvement,
                    decoration: _fieldDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: DomainInvolvement.none,
                        child: Text('Never'),
                      ),
                      DropdownMenuItem(
                        value: DomainInvolvement.occasional,
                        child: Text('Occasional'),
                      ),
                      DropdownMenuItem(
                        value: DomainInvolvement.regular,
                        child: Text('Regular'),
                      ),
                    ],
                    onChanged: disabled
                        ? null
                        : (value) {
                            if (value == null) return;
                            widget.onUpdate(
                              _ApplicationDomainPatch(involvement: value),
                            );
                          },
                  ),
                ),
                _Field(
                  label: 'Perceived value',
                  child: DropdownButtonFormField<DomainSignal>(
                    value: widget.domain.value,
                    decoration: _fieldDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: DomainSignal.low,
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: DomainSignal.moderate,
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(
                        value: DomainSignal.high,
                        child: Text('High'),
                      ),
                    ],
                    onChanged: disabled
                        ? null
                        : (value) {
                            if (value == null) return;
                            widget.onUpdate(
                              _ApplicationDomainPatch(value: value),
                            );
                          },
                  ),
                ),
                _Field(
                  label: 'Confidence',
                  child: DropdownButtonFormField<DomainSignal>(
                    value: widget.domain.confidence,
                    decoration: _fieldDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: DomainSignal.low,
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: DomainSignal.moderate,
                        child: Text('Moderate'),
                      ),
                      DropdownMenuItem(
                        value: DomainSignal.high,
                        child: Text('High'),
                      ),
                    ],
                    onChanged: disabled
                        ? null
                        : (value) {
                            if (value == null) return;
                            widget.onUpdate(
                              _ApplicationDomainPatch(confidence: value),
                            );
                          },
                  ),
                ),
                const Text(
                  'Linked capabilities',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: DashboardTheme.body,
                  ),
                ),
                const SizedBox(height: 8),
                for (final dimension in widget.dimensions)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: widget.domain.capabilityIds.contains(dimension.id),
                    onChanged: disabled
                        ? null
                        : (checked) {
                            final ids = List<int>.from(widget.domain.capabilityIds);
                            if (checked == true) {
                              ids.add(dimension.id);
                            } else {
                              ids.remove(dimension.id);
                            }
                            ids.sort();
                            widget.onUpdate(
                              _ApplicationDomainPatch(capabilityIds: ids),
                            );
                          },
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: DashboardTheme.parseHex(dimension.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dimension.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
