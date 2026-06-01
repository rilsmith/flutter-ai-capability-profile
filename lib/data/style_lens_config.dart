enum StyleSymbol {
  sword,
  shield,
  cog,
  banner,
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
    required this.sword,
    required this.shield,
    required this.cog,
    required this.banner,
  });

  final double sword;
  final double shield;
  final double cog;
  final double banner;

  double forSymbol(StyleSymbol symbol) => switch (symbol) {
        StyleSymbol.sword => sword,
        StyleSymbol.shield => shield,
        StyleSymbol.cog => cog,
        StyleSymbol.banner => banner,
      };

  double get total => sword + shield + cog + banner;
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
    StyleSymbol.sword: SymbolDefinition(
      emoji: '⚔️',
      label: 'Sword',
      shortDescription:
          'Implementation and execution — turning intent into working output with agents',
      color: '#DC2626',
      styleLabel: 'Hands-on Executor',
    ),
    StyleSymbol.shield: SymbolDefinition(
      emoji: '🛡️',
      label: 'Shield',
      shortDescription:
          'Reliability, assurance, and risk control — testing, oversight, governance',
      color: '#2563EB',
      styleLabel: 'Assurance Operator',
    ),
    StyleSymbol.cog: SymbolDefinition(
      emoji: '⚙️',
      label: 'Cog',
      shortDescription:
          'Tooling, infrastructure, and enablement — context, platforms, reusable systems',
      color: '#0D9488',
      styleLabel: 'Platform Enabler',
    ),
    StyleSymbol.banner: SymbolDefinition(
      emoji: '🚩',
      label: 'Banner',
      shortDescription:
          'Orchestration, coordination, and scaling — delegation, workflows, org adoption',
      color: '#7C3AED',
      styleLabel: 'Orchestration Catalyst',
    ),
  },
  dimensionWeights: {
    1: DimensionSymbolWeights(
      sword: 0.75,
      shield: 0.10,
      cog: 0.15,
      banner: 0.00,
    ),
    2: DimensionSymbolWeights(
      sword: 0.05,
      shield: 0.10,
      cog: 0.75,
      banner: 0.10,
    ),
    3: DimensionSymbolWeights(
      sword: 0.15,
      shield: 0.10,
      cog: 0.70,
      banner: 0.05,
    ),
    4: DimensionSymbolWeights(
      sword: 0.05,
      shield: 0.80,
      cog: 0.15,
      banner: 0.00,
    ),
    5: DimensionSymbolWeights(
      sword: 0.05,
      shield: 0.75,
      cog: 0.10,
      banner: 0.10,
    ),
    6: DimensionSymbolWeights(
      sword: 0.20,
      shield: 0.05,
      cog: 0.10,
      banner: 0.65,
    ),
    7: DimensionSymbolWeights(
      sword: 0.05,
      shield: 0.15,
      cog: 0.55,
      banner: 0.25,
    ),
    8: DimensionSymbolWeights(
      sword: 0.00,
      shield: 0.15,
      cog: 0.20,
      banner: 0.65,
    ),
    9: DimensionSymbolWeights(
      sword: 0.00,
      shield: 0.90,
      cog: 0.10,
      banner: 0.00,
    ),
  },
  focusBySymbol: {
    StyleSymbol.sword:
        'Strengthen hands-on execution loops — clearer task specs, tighter human-agent iteration.',
    StyleSymbol.shield:
        'Invest in assurance — eval harnesses, review checkpoints, explicit guardrails.',
    StyleSymbol.cog:
        'Build reusable enablement — context systems, skills, and infrastructure others can adopt.',
    StyleSymbol.banner:
        'Expand coordination — delegation patterns, workflow orchestration, team-wide integration.',
  },
  singleDominantNarrative:
      'Your profile reads as {dominantLabel}-first: {topDimension} and related capabilities pull your {dominantSymbol} score up. {weakestSymbol} work ({weakestLabel}) is lighter relative to your other strengths — a {spread} spread across symbols.',
  blendNarrative:
      'You blend {dominantLabels} — {topDimension} and related capabilities anchor your strongest symbols. {weakestSymbol} ({weakestLabel}) is relatively underrepresented today, with a {spread} spread across your profile.',
  balancedNarrative:
      'Your symbol scores cluster tightly — no single style dominates. You bring a balanced mix of execution, assurance, enablement, and coordination across capabilities.',
);
