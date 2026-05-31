import 'dart:math' as math;

import '../models/dimension.dart';
import '../models/distribution.dart';
import '../models/tier.dart';

double computeAverage(List<Dimension> dimensions) {
  final sum = dimensions.fold<double>(0, (acc, d) => acc + d.score);
  return (sum / dimensions.length * 10).roundToDouble() / 10;
}

Distribution computeDistribution(List<Dimension> dimensions, TierGroup tiers) {
  var high = 0;
  var medium = 0;
  var low = 0;

  for (final d in dimensions) {
    if (d.score >= tiers.high.min) {
      high++;
    } else if (d.score >= tiers.medium.min) {
      medium++;
    } else {
      low++;
    }
  }

  return Distribution(high: high, medium: medium, low: low);
}

({double x, double y}) polarToXY(
  double cx,
  double cy,
  double radius,
  double angleDeg,
) {
  final rad = (angleDeg - 90) * math.pi / 180;
  return (
    x: cx + radius * math.cos(rad),
    y: cy + radius * math.sin(rad),
  );
}

List<String> wrapDescriptor(String text, int maxChars) {
  final words = text.split(RegExp(r',\s*'));
  final lines = <String>[];
  var current = '';

  for (final part in words) {
    final candidate = current.isEmpty ? part : '$current, $part';
    if (candidate.length > maxChars && current.isNotEmpty) {
      lines.add(current);
      current = part;
    } else {
      current = candidate;
    }
  }

  if (current.isNotEmpty) {
    lines.add(current);
  }

  return lines.take(2).toList();
}

double clampScore(double score, int maxScore) {
  return math.min(maxScore.toDouble(), math.max(1, (score * 10).roundToDouble() / 10));
}

double scoreFromAxisPoint(
  double x,
  double y,
  double cx,
  double cy,
  double angleDeg,
  double maxRadius,
  int maxScore,
) {
  final axisEnd = polarToXY(cx, cy, maxRadius, angleDeg);
  final ux = (axisEnd.x - cx) / maxRadius;
  final uy = (axisEnd.y - cy) / maxRadius;
  final projection = (x - cx) * ux + (y - cy) * uy;
  final clampedRadius = math.max(0, math.min(maxRadius, projection));
  return clampScore((clampedRadius / maxRadius) * maxScore, maxScore);
}

int nearestDimensionIndex(
  double x,
  double y,
  double cx,
  double cy,
  int dimensionCount,
) {
  var angleDeg = math.atan2(y - cy, x - cx) * 180 / math.pi + 90;
  angleDeg = (angleDeg + 360) % 360;
  final angleStep = 360 / dimensionCount;
  var index = (angleDeg / angleStep).round() % dimensionCount;
  if (index < 0) {
    index += dimensionCount;
  }
  return index;
}

double distanceToAxis(
  double x,
  double y,
  double cx,
  double cy,
  double angleDeg,
) {
  final axisEnd = polarToXY(cx, cy, 1, angleDeg);
  final ux = axisEnd.x - cx;
  final uy = axisEnd.y - cy;
  final projection = (x - cx) * ux + (y - cy) * uy;
  final perpX = x - cx - projection * ux;
  final perpY = y - cy - projection * uy;
  return math.sqrt(perpX * perpX + perpY * perpY);
}
