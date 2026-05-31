import '../data/style_lens_config.dart';

class SymbolContribution {
  const SymbolContribution({
    required this.dimensionId,
    required this.dimensionName,
    required this.weight,
    required this.score,
  });

  final int dimensionId;
  final String dimensionName;
  final double weight;
  final double score;
}

class StyleLensAnalysis {
  const StyleLensAnalysis({
    required this.scores,
    required this.dominantSymbols,
    required this.weakestSymbols,
    required this.headline,
    required this.narrative,
    required this.strengths,
    required this.watchouts,
    required this.suggestedFocus,
    required this.contributionsBySymbol,
    this.selectedDimensionHint,
  });

  final Map<StyleSymbol, double> scores;
  final List<StyleSymbol> dominantSymbols;
  final List<StyleSymbol> weakestSymbols;
  final String headline;
  final String narrative;
  final List<String> strengths;
  final List<String> watchouts;
  final String suggestedFocus;
  final Map<StyleSymbol, List<SymbolContribution>> contributionsBySymbol;
  final String? selectedDimensionHint;

  double scoreFor(StyleSymbol symbol) => scores[symbol] ?? 0;

  bool isDominant(StyleSymbol symbol) => dominantSymbols.contains(symbol);
}
