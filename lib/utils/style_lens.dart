import 'package:flutter/foundation.dart';

import '../data/style_lens_config.dart';
import '../models/dimension.dart';
import '../models/style_lens_analysis.dart';
import '../models/tier.dart';

StyleLensAnalysis computeStyleLens(
  List<Dimension> dimensions, {
  StyleLensConfig config = styleLensConfig,
  required TierGroup tiers,
  required int maxScore,
  int? selectedDimensionId,
}) {
  final scores = _computeSymbolScores(dimensions, config);
  final contributions = _computeContributions(dimensions, config);
  final ranked = StyleSymbol.values.toList()
    ..sort((a, b) => scores[b]!.compareTo(scores[a]!));

  final isBalanced = _isBalancedProfile(scores, config.blendThreshold);

  final dominantSymbols = isBalanced
      ? List<StyleSymbol>.from(StyleSymbol.values)
      : _dominantSymbols(scores, ranked, config.blendThreshold);

  final weakestSymbols = _weakestSymbols(
    scores,
    ranked,
    config.weakestTieThreshold,
  );

  final headline = _buildHeadline(dominantSymbols, isBalanced, config);
  final narrative = _buildNarrative(
    config: config,
    scores: scores,
    dominantSymbols: dominantSymbols,
    weakestSymbols: weakestSymbols,
    contributions: contributions,
    isBalanced: isBalanced,
  );
  final strengths = _buildStrengths(
    ranked: ranked,
    scores: scores,
    contributions: contributions,
    tiers: tiers,
    config: config,
    isBalanced: isBalanced,
  );
  final watchouts = _buildWatchouts(
    ranked: ranked,
    scores: scores,
    contributions: contributions,
    tiers: tiers,
    config: config,
    isBalanced: isBalanced,
  );
  final suggestedFocus = _buildSuggestedFocus(
    weakestSymbols: weakestSymbols,
    scores: scores,
    config: config,
  );
  final selectedDimensionHint = selectedDimensionId == null
      ? null
      : _buildSelectedDimensionHint(
          selectedDimensionId,
          dimensions,
          config,
        );

  return StyleLensAnalysis(
    scores: scores,
    dominantSymbols: dominantSymbols,
    weakestSymbols: weakestSymbols,
    headline: headline,
    narrative: narrative,
    strengths: strengths,
    watchouts: watchouts,
    suggestedFocus: suggestedFocus,
    contributionsBySymbol: contributions,
    selectedDimensionHint: selectedDimensionHint,
  );
}

Map<StyleSymbol, double> _computeSymbolScores(
  List<Dimension> dimensions,
  StyleLensConfig config,
) {
  final weightedSums = {
    for (final symbol in StyleSymbol.values) symbol: 0.0,
  };
  final weightTotals = {
    for (final symbol in StyleSymbol.values) symbol: 0.0,
  };

  for (final dimension in dimensions) {
    final weights = config.dimensionWeights[dimension.id];
    if (weights == null) {
      assert(() {
        debugPrint(
          'Style lens: missing weights for dimension id ${dimension.id}',
        );
        return false;
      }());
      continue;
    }

    for (final symbol in StyleSymbol.values) {
      final weight = weights.forSymbol(symbol);
      if (weight <= 0) continue;
      weightedSums[symbol] = weightedSums[symbol]! + weight * dimension.score;
      weightTotals[symbol] = weightTotals[symbol]! + weight;
    }
  }

  return {
    for (final symbol in StyleSymbol.values)
      symbol: weightTotals[symbol]! > 0
          ? _roundScore(weightedSums[symbol]! / weightTotals[symbol]!)
          : 0.0,
  };
}

Map<StyleSymbol, List<SymbolContribution>> _computeContributions(
  List<Dimension> dimensions,
  StyleLensConfig config,
) {
  final contributions = {
    for (final symbol in StyleSymbol.values) symbol: <SymbolContribution>[],
  };

  for (final dimension in dimensions) {
    final weights = config.dimensionWeights[dimension.id];
    if (weights == null) continue;

    for (final symbol in StyleSymbol.values) {
      final weight = weights.forSymbol(symbol);
      if (weight <= 0) continue;
      contributions[symbol]!.add(
        SymbolContribution(
          dimensionId: dimension.id,
          dimensionName: dimension.name,
          weight: weight,
          score: dimension.score,
        ),
      );
    }
  }

  for (final symbol in StyleSymbol.values) {
    contributions[symbol]!.sort((a, b) => b.weight.compareTo(a.weight));
  }

  return contributions;
}

bool _isBalancedProfile(
  Map<StyleSymbol, double> scores,
  double blendThreshold,
) {
  final values = scores.values.toList();
  final maxScore = values.reduce((a, b) => a > b ? a : b);
  final minScore = values.reduce((a, b) => a < b ? a : b);
  return maxScore - minScore <= blendThreshold;
}

List<StyleSymbol> _dominantSymbols(
  Map<StyleSymbol, double> scores,
  List<StyleSymbol> ranked,
  double blendThreshold,
) {
  final topScore = scores[ranked.first]!;
  return ranked
      .where((symbol) => topScore - scores[symbol]! <= blendThreshold)
      .toList();
}

List<StyleSymbol> _weakestSymbols(
  Map<StyleSymbol, double> scores,
  List<StyleSymbol> ranked,
  double tieThreshold,
) {
  final bottomScore = scores[ranked.last]!;
  final weakest = ranked
      .where((symbol) => scores[symbol]! - bottomScore <= tieThreshold)
      .toList();
  return weakest.reversed.toList();
}

String _buildHeadline(
  List<StyleSymbol> dominantSymbols,
  bool isBalanced,
  StyleLensConfig config,
) {
  if (isBalanced) {
    return 'Balanced across all four styles';
  }

  if (dominantSymbols.length == 1) {
    final symbol = dominantSymbols.first;
    return '${config.symbols[symbol]!.label}-led profile';
  }

  final labels = dominantSymbols
      .map((symbol) => config.symbols[symbol]!.label)
      .join(' & ');
  return '$labels-led profile';
}

String _buildNarrative({
  required StyleLensConfig config,
  required Map<StyleSymbol, double> scores,
  required List<StyleSymbol> dominantSymbols,
  required List<StyleSymbol> weakestSymbols,
  required Map<StyleSymbol, List<SymbolContribution>> contributions,
  required bool isBalanced,
}) {
  if (isBalanced) {
    return config.balancedNarrative;
  }

  final spread = _describeSpread(scores);
  final topDimension = _topContributingDimensionName(
    dominantSymbols.first,
    contributions,
  );
  final weakestSymbol = weakestSymbols.first;
  final weakestLabel = config.symbols[weakestSymbol]!.styleLabel;

  if (dominantSymbols.length == 1) {
    final dominantSymbol = dominantSymbols.first;
    return config.singleDominantNarrative
        .replaceAll('{dominantLabel}', config.symbols[dominantSymbol]!.styleLabel)
        .replaceAll('{dominantSymbol}', config.symbols[dominantSymbol]!.label)
        .replaceAll('{topDimension}', topDimension)
        .replaceAll('{weakestSymbol}', config.symbols[weakestSymbol]!.label)
        .replaceAll('{weakestLabel}', weakestLabel)
        .replaceAll('{spread}', spread);
  }

  final dominantLabels = dominantSymbols
      .map((symbol) => config.symbols[symbol]!.styleLabel)
      .join(' and ');
  return config.blendNarrative
      .replaceAll('{dominantLabels}', dominantLabels)
      .replaceAll('{topDimension}', topDimension)
      .replaceAll('{weakestSymbol}', config.symbols[weakestSymbol]!.label)
      .replaceAll('{weakestLabel}', weakestLabel)
      .replaceAll('{spread}', spread);
}

List<String> _buildStrengths({
  required List<StyleSymbol> ranked,
  required Map<StyleSymbol, double> scores,
  required Map<StyleSymbol, List<SymbolContribution>> contributions,
  required TierGroup tiers,
  required StyleLensConfig config,
  required bool isBalanced,
}) {
  if (isBalanced) {
    return [
      'Even distribution across Sword, Shield, Cog, and Banner — no single style dominates.',
      'Capability investment appears spread across execution, assurance, enablement, and coordination.',
    ];
  }

  final strengths = <String>[];
  final topSymbols = _dominantSymbols(scores, ranked, config.blendThreshold);

  for (final symbol in topSymbols.take(2)) {
    final dimension = _pickStrengthDimension(
      contributions[symbol]!,
      tiers.medium.min,
    );
    if (dimension == null) {
      strengths.add(
        '${config.symbols[symbol]!.emoji} ${config.symbols[symbol]!.label} '
        '(${scores[symbol]!.toStringAsFixed(1)}) is a relative strength.',
      );
    } else {
      strengths.add(
        '${config.symbols[symbol]!.emoji} ${config.symbols[symbol]!.label} '
        'is lifted by ${dimension.dimensionName} (${dimension.score.toStringAsFixed(1)}).',
      );
    }
  }

  return strengths;
}

List<String> _buildWatchouts({
  required List<StyleSymbol> ranked,
  required Map<StyleSymbol, double> scores,
  required Map<StyleSymbol, List<SymbolContribution>> contributions,
  required TierGroup tiers,
  required StyleLensConfig config,
  required bool isBalanced,
}) {
  if (isBalanced) {
    return [
      'No symbol is significantly underdeveloped — revisit goals if you want to specialize.',
    ];
  }

  final watchouts = <String>[];
  final weakest = _weakestSymbols(
    scores,
    ranked,
    config.weakestTieThreshold,
  );

  for (final symbol in weakest.take(2)) {
    final dimension = _pickWatchoutDimension(
      contributions[symbol]!,
      tiers.medium.min,
    );
    if (dimension == null) {
      watchouts.add(
        '${config.symbols[symbol]!.emoji} ${config.symbols[symbol]!.label} '
        '(${scores[symbol]!.toStringAsFixed(1)}) is lighter relative to your other symbols.',
      );
    } else {
      watchouts.add(
        '${config.symbols[symbol]!.emoji} ${config.symbols[symbol]!.label} '
        'has room to develop — ${dimension.dimensionName} (${dimension.score.toStringAsFixed(1)}) contributes most.',
      );
    }
  }

  return watchouts;
}

String _buildSuggestedFocus({
  required List<StyleSymbol> weakestSymbols,
  required Map<StyleSymbol, double> scores,
  required StyleLensConfig config,
}) {
  if (weakestSymbols.length == 1) {
    return config.focusBySymbol[weakestSymbols.first]!;
  }

  final bottomScore = scores[weakestSymbols.first]!;
  final tied = weakestSymbols
      .where((symbol) => (scores[symbol]! - bottomScore).abs() <= 0.01)
      .toList();

  if (tied.length <= 1) {
    return config.focusBySymbol[weakestSymbols.first]!;
  }

  final parts =
      tied.map((symbol) => config.focusBySymbol[symbol]!).toList();
  return parts.join(' Also, ');
}

SymbolContribution? _pickStrengthDimension(
  List<SymbolContribution> contributions,
  double mediumMin,
) {
  for (final contribution in contributions) {
    if (contribution.score >= mediumMin) {
      return contribution;
    }
  }
  return contributions.isEmpty ? null : contributions.first;
}

SymbolContribution? _pickWatchoutDimension(
  List<SymbolContribution> contributions,
  double mediumMin,
) {
  for (final contribution in contributions) {
    if (contribution.score < mediumMin) {
      return contribution;
    }
  }

  if (contributions.isEmpty) return null;

  return contributions.reduce(
    (best, current) => current.score < best.score ? current : best,
  );
}

String _topContributingDimensionName(
  StyleSymbol symbol,
  Map<StyleSymbol, List<SymbolContribution>> contributions,
) {
  final top = contributions[symbol];
  if (top == null || top.isEmpty) return 'your capabilities';
  return top.first.dimensionName;
}

String _describeSpread(Map<StyleSymbol, double> scores) {
  final values = scores.values.toList();
  final spread = values.reduce((a, b) => a > b ? a : b) -
      values.reduce((a, b) => a < b ? a : b);

  if (spread <= 0.35) return 'tight';
  if (spread <= 0.75) return 'moderate';
  return 'wide';
}

String? _buildSelectedDimensionHint(
  int dimensionId,
  List<Dimension> dimensions,
  StyleLensConfig config,
) {
  final dimension = dimensions.where((d) => d.id == dimensionId).firstOrNull;
  final weights = config.dimensionWeights[dimensionId];
  if (dimension == null || weights == null) return null;

  StyleSymbol? topSymbol;
  var topWeight = -1.0;
  for (final symbol in StyleSymbol.values) {
    final weight = weights.forSymbol(symbol);
    if (weight > topWeight) {
      topWeight = weight;
      topSymbol = symbol;
    }
  }

  if (topSymbol == null || topWeight <= 0) return null;

  final symbolDef = config.symbols[topSymbol]!;
  final percent = (topWeight * 100).round();
  return '${dimension.name} contributes most to ${symbolDef.emoji} ${symbolDef.label} ($percent%).';
}

double _roundScore(double value) => (value * 10).roundToDouble() / 10;

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
