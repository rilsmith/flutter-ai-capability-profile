enum StyleSymbol {
  warrior,
  paladin,
  artificer,
  commander,
}

class SymbolDefinition {
  const SymbolDefinition({
    required this.emoji,
    required this.label,
    required this.shortDescription,
    required this.color,
    required this.styleLabel,
  });

  final String emoji;
  final String label;
  final String shortDescription;
  final String color;
  final String styleLabel;
}

class DimensionSymbolWeights {
  const DimensionSymbolWeights({
    required this.warrior,
    required this.paladin,
    required this.artificer,
    required this.commander,
  });

  final double warrior;
  final double paladin;
  final double artificer;
  final double commander;

  double forSymbol(StyleSymbol symbol) => switch (symbol) {
        StyleSymbol.warrior => warrior,
        StyleSymbol.paladin => paladin,
        StyleSymbol.artificer => artificer,
        StyleSymbol.commander => commander,
      };

  double get total => warrior + paladin + artificer + commander;
}

class StyleLensConfig {
  const StyleLensConfig({
    required this.title,
    required this.subtitle,
    required this.blendThreshold,
    required this.weakestTieThreshold,
    required this.symbols,
    required this.dimensionWeights,
    required this.focusBySymbol,
    required this.singleDominantNarrative,
    required this.blendNarrative,
    required this.balancedNarrative,
  });

  final String title;
  final String subtitle;
  final double blendThreshold;
  final double weakestTieThreshold;
  final Map<StyleSymbol, SymbolDefinition> symbols;
  final Map<int, DimensionSymbolWeights> dimensionWeights;
  final Map<StyleSymbol, String> focusBySymbol;
  final String singleDominantNarrative;
  final String blendNarrative;
  final String balancedNarrative;
}

const styleLensConfig = StyleLensConfig(
  title: 'Engineering Style Lens',
  subtitle:
      'How your capability scores cluster into four working styles — descriptive, not a linear progression.',
  blendThreshold: 0.35,
  weakestTieThreshold: 0.15,
  symbols: {
    StyleSymbol.warrior: SymbolDefinition(
      emoji: '⚔️',
      label: 'Warrior',
      shortDescription:
          'Implementation and execution — turning intent into working output with agents',
      color: '#DC2626',
      styleLabel: 'Hands-on Executor',
    ),
    StyleSymbol.paladin: SymbolDefinition(
      emoji: '🛡️',
      label: 'Paladin',
      shortDescription:
          'Reliability, assurance, and risk control — testing, oversight, governance',
      color: '#2563EB',
      styleLabel: 'Assurance Operator',
    ),
    StyleSymbol.artificer: SymbolDefinition(
      emoji: '⚙️',
      label: 'Artificer',
      shortDescription:
          'Tooling, infrastructure, and enablement — context, platforms, reusable systems',
      color: '#0D9488',
      styleLabel: 'Platform Enabler',
    ),
    StyleSymbol.commander: SymbolDefinition(
      emoji: '🚩',
      label: 'Commander',
      shortDescription:
          'Orchestration, coordination, and scaling — delegation, workflows, org adoption',
      color: '#7C3AED',
      styleLabel: 'Orchestration Catalyst',
    ),
  },
  dimensionWeights: {
    1: DimensionSymbolWeights(
      warrior: 0.75,
      paladin: 0.10,
      artificer: 0.15,
      commander: 0.00,
    ),
    2: DimensionSymbolWeights(
      warrior: 0.05,
      paladin: 0.10,
      artificer: 0.75,
      commander: 0.10,
    ),
    3: DimensionSymbolWeights(
      warrior: 0.15,
      paladin: 0.10,
      artificer: 0.70,
      commander: 0.05,
    ),
    4: DimensionSymbolWeights(
      warrior: 0.05,
      paladin: 0.75,
      artificer: 0.10,
      commander: 0.10,
    ),
    5: DimensionSymbolWeights(
      warrior: 0.00,
      paladin: 0.15,
      artificer: 0.20,
      commander: 0.65,
    ),
  },
  focusBySymbol: {
    StyleSymbol.warrior:
        'Strengthen hands-on execution loops — clearer task specs, tighter human-agent iteration.',
    StyleSymbol.paladin:
        'Invest in assurance — eval harnesses, review checkpoints, explicit guardrails.',
    StyleSymbol.artificer:
        'Build reusable enablement — context systems, skills, and infrastructure others can adopt.',
    StyleSymbol.commander:
        'Expand coordination — delegation patterns, workflow orchestration, team-wide integration.',
  },
  singleDominantNarrative:
      'Your profile reads as {dominantLabel}-first: {topDimension} and related capabilities pull your {dominantSymbol} score up. {weakestSymbol} work ({weakestLabel}) is lighter relative to your other strengths — a {spread} spread across symbols.',
  blendNarrative:
      'You blend {dominantLabels} — {topDimension} and related capabilities anchor your strongest symbols. {weakestSymbol} ({weakestLabel}) is relatively underrepresented today, with a {spread} spread across your profile.',
  balancedNarrative:
      'Your symbol scores cluster tightly — no single style dominates. You bring a balanced mix of execution, assurance, enablement, and coordination across capabilities.',
);
