import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dimension.dart';
import '../models/individual_profile.dart';
import '../theme/dashboard_theme.dart';
import '../utils/compute.dart';

const _viewBox = 1100.0;
const _cx = 550.0;
const _cy = 550.0;
const _maxRadius = 240.0;
const _labelOffset = 40.0;
const _axisHitWidth = 24.0;
const _dotHitRadius = 18.0;

class InteractiveRadarChart extends StatefulWidget {
  const InteractiveRadarChart({
    super.key,
    required this.dimensions,
    required this.maxScore,
    this.editing = false,
    this.selectedDimensionId,
    this.onSelectDimension,
    this.onUpdateScore,
    this.teamMembers,
    this.teamMins,
    this.teamMaxs,
    this.highlightedMemberIndex,
  });

  final List<Dimension> dimensions;
  final int maxScore;
  final bool editing;
  final int? selectedDimensionId;
  final ValueChanged<int>? onSelectDimension;
  final void Function(int id, double score)? onUpdateScore;
  final List<IndividualProfile>? teamMembers;
  final List<double>? teamMins;
  final List<double>? teamMaxs;
  final int? highlightedMemberIndex;

  bool get isTeamView => teamMembers != null && teamMembers!.length > 1;

  @override
  State<InteractiveRadarChart> createState() => _InteractiveRadarChartState();
}

class _InteractiveRadarChartState extends State<InteractiveRadarChart> {
  int? _draggingId;
  bool _dragMoved = false;

  bool get _canDrag => widget.onUpdateScore != null && !widget.isTeamView;
  bool get _canSelect => widget.onSelectDimension != null;

  double get _angleStep => 360 / widget.dimensions.length;

  Offset _pointForIndex(int index, double score) {
    final polar = polarToXY(
      _cx,
      _cy,
      (score / widget.maxScore) * _maxRadius,
      index * _angleStep,
    );
    return Offset(polar.x, polar.y);
  }

  Offset _pointForDimension(int index) {
    final dimension = widget.dimensions[index];
    return _pointForIndex(index, dimension.score);
  }

  void _applyScore(int dimensionId, Offset viewBox) {
    final index = widget.dimensions.indexWhere((d) => d.id == dimensionId);
    if (index == -1) return;

    final score = scoreFromAxisPoint(
      viewBox.dx,
      viewBox.dy,
      _cx,
      _cy,
      index * _angleStep,
      _maxRadius,
      widget.maxScore,
    );
    widget.onUpdateScore!(dimensionId, score);
  }

  void _handleAxisTap(Offset viewBox) {
    if (!_canDrag || _draggingId != null) return;

    final index = nearestDimensionIndex(
      viewBox.dx,
      viewBox.dy,
      _cx,
      _cy,
      widget.dimensions.length,
    );
    final angleDeg = index * _angleStep;

    if (distanceToAxis(viewBox.dx, viewBox.dy, _cx, _cy, angleDeg) >
        _axisHitWidth / 2) {
      return;
    }

    final dimension = widget.dimensions[index];
    _applyScore(dimension.id, viewBox);
    if (_canSelect) {
      widget.onSelectDimension!(dimension.id);
    }
  }

  void _startDotDrag(int dimensionId) {
    _dragMoved = false;
    setState(() => _draggingId = dimensionId);
    if (_canSelect && widget.editing) {
      widget.onSelectDimension!(dimensionId);
    }
  }

  void _moveDotDrag(Offset viewBox) {
    if (_draggingId == null) return;
    _dragMoved = true;
    _applyScore(_draggingId!, viewBox);
  }

  void _endDotDrag(int dimensionId, Offset viewBox) {
    if (_draggingId != dimensionId) return;

    if (!_dragMoved) {
      _applyScore(dimensionId, viewBox);
    }
    if (_canSelect && !_dragMoved) {
      widget.onSelectDimension!(dimensionId);
    }
    setState(() => _draggingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _viewBox,
          height: _viewBox,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerMove: (event) {
              if (_draggingId != null) {
                _moveDotDrag(event.localPosition);
              }
            },
            onPointerUp: (event) {
              if (_draggingId != null) {
                _endDotDrag(_draggingId!, event.localPosition);
              }
            },
            onPointerCancel: (event) {
              if (_draggingId != null) {
                setState(() => _draggingId = null);
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: const Size(_viewBox, _viewBox),
                  painter: _RadarVisualPainter(
                    dimensions: widget.dimensions,
                    maxScore: widget.maxScore,
                    selectedDimensionId: widget.selectedDimensionId,
                    draggingId: _draggingId,
                    teamMembers: widget.teamMembers,
                    teamMins: widget.teamMins,
                    teamMaxs: widget.teamMaxs,
                    highlightedMemberIndex: widget.highlightedMemberIndex,
                  ),
                ),
                if (_canDrag)
                  Positioned(
                    left: _cx - _maxRadius,
                    top: _cy - _maxRadius,
                    width: _maxRadius * 2,
                    height: _maxRadius * 2,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.precise,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: (details) {
                          final viewBox = Offset(
                            _cx - _maxRadius + details.localPosition.dx,
                            _cy - _maxRadius + details.localPosition.dy,
                          );
                          _handleAxisTap(viewBox);
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                if (_canDrag)
                  for (var i = 0; i < widget.dimensions.length; i++)
                    _DotHitTarget(
                      key: ValueKey(widget.dimensions[i].id),
                      center: _pointForDimension(i),
                      dragging: _draggingId == widget.dimensions[i].id,
                      onDragStart: () =>
                          _startDotDrag(widget.dimensions[i].id),
                    ),
                for (var i = 0; i < widget.dimensions.length; i++)
                  _DimensionLabel(
                    key: ValueKey('label-${widget.dimensions[i].id}'),
                    dimension: widget.dimensions[i],
                    angleDeg: i * _angleStep,
                    isSelected:
                        widget.selectedDimensionId == widget.dimensions[i].id,
                    canSelect: _canSelect,
                    onSelect: _canSelect
                        ? () =>
                            widget.onSelectDimension!(widget.dimensions[i].id)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotHitTarget extends StatelessWidget {
  const _DotHitTarget({
    super.key,
    required this.center,
    required this.dragging,
    required this.onDragStart,
  });

  final Offset center;
  final bool dragging;
  final VoidCallback onDragStart;

  @override
  Widget build(BuildContext context) {
    final size = _dotHitRadius * 2;
    return Positioned(
      left: center.dx - _dotHitRadius,
      top: center.dy - _dotHitRadius,
      width: size,
      height: size,
      child: MouseRegion(
        cursor: dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => onDragStart(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _DimensionLabel extends StatelessWidget {
  const _DimensionLabel({
    super.key,
    required this.dimension,
    required this.angleDeg,
    required this.isSelected,
    required this.canSelect,
    this.onSelect,
  });

  final Dimension dimension;
  final double angleDeg;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final normalized = ((angleDeg % 360) + 360) % 360;
    final descLines = wrapDescriptor(
      dimension.descriptor,
      normalized > 30 && normalized < 150 ? 22 : 26,
    );
    final pos = polarToXY(_cx, _cy, _maxRadius + _labelOffset, angleDeg);
    final color = DashboardTheme.parseHex(dimension.color);

    TextAlign textAlign;
    CrossAxisAlignment crossAlign;
    double dx;
    double anchorX;

    if (normalized > 10 && normalized < 170) {
      textAlign = TextAlign.left;
      crossAlign = CrossAxisAlignment.start;
      dx = 4;
      anchorX = 0;
    } else if (normalized > 190 && normalized < 350) {
      textAlign = TextAlign.right;
      crossAlign = CrossAxisAlignment.end;
      dx = -4;
      anchorX = 1;
    } else {
      textAlign = TextAlign.center;
      crossAlign = CrossAxisAlignment.center;
      dx = 0;
      anchorX = 0.5;
    }

    final titleStyle = TextStyle(
      fontSize: 24,
      height: 1.15,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
      color: color,
    );
    final descStyle = TextStyle(
      fontSize: 20,
      height: 1.15,
      color: DashboardTheme.muted.withValues(
        alpha: isSelected ? 1 : (canSelect ? 0.92 : 1),
      ),
    );

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAlign,
      children: [
        Text(
          '${dimension.id}. ${dimension.name}',
          textAlign: textAlign,
          softWrap: false,
          style: titleStyle,
        ),
        for (final line in descLines)
          Text(
            line,
            textAlign: textAlign,
            style: descStyle,
          ),
      ],
    );

    return Positioned(
      left: pos.x + dx,
      top: pos.y,
      child: FractionalTranslation(
        translation: Offset(-anchorX, -0.5),
        child: GestureDetector(
          onTap: onSelect,
          behavior: HitTestBehavior.translucent,
          child: MouseRegion(
            cursor: canSelect
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: label,
          ),
        ),
      ),
    );
  }
}

class _RadarVisualPainter extends CustomPainter {
  _RadarVisualPainter({
    required this.dimensions,
    required this.maxScore,
    required this.selectedDimensionId,
    required this.draggingId,
    this.teamMembers,
    this.teamMins,
    this.teamMaxs,
    this.highlightedMemberIndex,
  });

  final List<Dimension> dimensions;
  final int maxScore;
  final int? selectedDimensionId;
  final int? draggingId;
  final List<IndividualProfile>? teamMembers;
  final List<double>? teamMins;
  final List<double>? teamMaxs;
  final int? highlightedMemberIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final n = dimensions.length;
    final angleStep = 360 / n;
    final gridPaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final axisPaint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= maxScore; level++) {
      final r = (level / maxScore) * _maxRadius;
      canvas.drawCircle(Offset(_cx, _cy), r, gridPaint);
    }

    for (var i = maxScore - 1; i >= 1; i--) {
      final r = ((i + 1) / maxScore) * _maxRadius;
      canvas.drawCircle(
        Offset(_cx, _cy),
        r,
        Paint()
          ..color = i.isOdd
              ? const Color(0x08000000)
              : const Color(0x00000000)
          ..style = PaintingStyle.fill,
      );
    }

    for (var i = 0; i < n; i++) {
      final end = polarToXY(_cx, _cy, _maxRadius, i * angleStep);
      _drawDashedLine(
        canvas,
        Offset(_cx, _cy),
        Offset(end.x, end.y),
        axisPaint,
      );
    }

    for (var level = 1; level <= maxScore; level++) {
      final r = (level / maxScore) * _maxRadius;
      final pos = polarToXY(_cx, _cy, r, 0);
      final painter = TextPainter(
        text: TextSpan(
          text: '$level',
          style: const TextStyle(fontSize: 16, color: DashboardTheme.subtle),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(pos.x - 20 - painter.width, pos.y + 4 - painter.height / 2),
      );
    }

    _drawTeamRange(canvas, n, angleStep);
    _drawDataPolygon(canvas, n, angleStep);
    _drawIndividualDots(canvas, n, angleStep);
    _drawDimensionDots(canvas, n, angleStep);
  }

  void _drawTeamRange(Canvas canvas, int n, double angleStep) {
    if (teamMins == null || teamMaxs == null) return;
    if (teamMins!.length < n || teamMaxs!.length < n) return;

    final minPoints = <Offset>[];
    final maxPoints = <Offset>[];

    for (var i = 0; i < n; i++) {
      final minP = polarToXY(
        _cx, _cy,
        (teamMins![i] / maxScore) * _maxRadius,
        i * angleStep,
      );
      final maxP = polarToXY(
        _cx, _cy,
        (teamMaxs![i] / maxScore) * _maxRadius,
        i * angleStep,
      );
      minPoints.add(Offset(minP.x, minP.y));
      maxPoints.add(Offset(maxP.x, maxP.y));
    }

    final fillPaint = Paint()
      ..color = const Color(0x122563EB)
      ..style = PaintingStyle.fill;

    if (minPoints.length >= 3) {
      final path = Path()..moveTo(minPoints.first.dx, minPoints.first.dy);
      for (final point in minPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    }

    if (maxPoints.length >= 3) {
      final path = Path()..moveTo(maxPoints.first.dx, maxPoints.first.dy);
      for (final point in maxPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, fillPaint);

      final borderPaint = Paint()
        ..color = const Color(0x402563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawPath(path, borderPaint);
    }

    if (minPoints.length >= 3) {
      final borderPaint = Paint()
        ..color = const Color(0x402563EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      final path = Path()..moveTo(minPoints.first.dx, minPoints.first.dy);
      for (final point in minPoints.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, borderPaint);
    }
  }

  void _drawDataPolygon(Canvas canvas, int n, double angleStep) {
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final dimension = dimensions[i];
      final point = polarToXY(
        _cx, _cy,
        (dimension.score / maxScore) * _maxRadius,
        i * angleStep,
      );
      points.add(Offset(point.x, point.y));
    }

    if (points.length >= 3) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0x262563EB)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = DashboardTheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawIndividualDots(Canvas canvas, int n, double angleStep) {
    if (teamMembers == null) return;
    final memberColors = [
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

    for (var mi = 0; mi < teamMembers!.length; mi++) {
      final member = teamMembers![mi];
      final color = memberColors[mi % memberColors.length];
      if (member.scores.length < n) continue;

      final isHighlighted = highlightedMemberIndex == mi;

      for (var i = 0; i < n; i++) {
        final point = polarToXY(
          _cx, _cy,
          (member.scores[i] / maxScore) * _maxRadius,
          i * angleStep,
        );
        final offset = Offset(point.x, point.y);

        if (isHighlighted) {
          canvas.drawCircle(
            offset,
            6,
            Paint()
              ..color = color.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
        }

        canvas.drawCircle(
          offset,
          isHighlighted ? 5 : 3,
          Paint()..color = color.withValues(alpha: isHighlighted ? 1.0 : 0.7),
        );
        canvas.drawCircle(
          offset,
          isHighlighted ? 5 : 3,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawDimensionDots(Canvas canvas, int n, double angleStep) {
    for (var i = 0; i < n; i++) {
      final dimension = dimensions[i];
      final point = polarToXY(
        _cx, _cy,
        (dimension.score / maxScore) * _maxRadius,
        i * angleStep,
      );
      final offset = Offset(point.x, point.y);
      final isSelected = selectedDimensionId == dimension.id;
      final isDragging = draggingId == dimension.id;
      final color = DashboardTheme.parseHex(dimension.color);

      if (isSelected || isDragging) {
        canvas.drawCircle(
          offset,
          9,
          Paint()
            ..color = color.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      canvas.drawCircle(
        offset,
        isSelected || isDragging ? 5 : 4,
        Paint()..color = color,
      );
      canvas.drawCircle(
        offset,
        isSelected || isDragging ? 5 : 4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final delta = end - start;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    var traveled = 0.0;
    while (traveled < length) {
      canvas.drawLine(
        start + direction * traveled,
        start + direction * math.min(traveled + dash, length),
        paint,
      );
      traveled += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RadarVisualPainter oldDelegate) {
    return oldDelegate.dimensions != dimensions ||
        oldDelegate.maxScore != maxScore ||
        oldDelegate.selectedDimensionId != selectedDimensionId ||
        oldDelegate.draggingId != draggingId ||
        oldDelegate.teamMembers != teamMembers ||
        oldDelegate.teamMins != teamMins ||
        oldDelegate.teamMaxs != teamMaxs ||
        oldDelegate.highlightedMemberIndex != highlightedMemberIndex;
  }
}