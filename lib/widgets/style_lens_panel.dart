import 'package:flutter/material.dart';

import '../data/style_lens_config.dart';
import '../models/style_lens_analysis.dart';
import '../theme/dashboard_theme.dart';

class StyleLensPanel extends StatelessWidget {
  const StyleLensPanel({
    super.key,
    required this.analysis,
    required this.config,
    required this.maxScore,
  });

  final StyleLensAnalysis analysis;
  final StyleLensConfig config;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(config.title, style: DashboardTheme.cardHeading),
          const SizedBox(height: 8),
          Text(
            config.subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: DashboardTheme.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _SymbolLegend(config: config),
          const SizedBox(height: 16),
          _SymbolScoreGrid(
            analysis: analysis,
            config: config,
            maxScore: maxScore,
          ),
          const SizedBox(height: 16),
          Text(
            analysis.headline,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: DashboardTheme.heading,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            analysis.narrative,
            style: const TextStyle(
              fontSize: 14,
              color: DashboardTheme.body,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _BulletSection(title: 'Strengths', items: analysis.strengths),
          const SizedBox(height: 12),
          _BulletSection(title: 'Watchouts', items: analysis.watchouts),
          const SizedBox(height: 16),
          Text('Suggested focus', style: DashboardTheme.cardHeading),
          const SizedBox(height: 6),
          Text(
            analysis.suggestedFocus,
            style: const TextStyle(
              fontSize: 14,
              color: DashboardTheme.body,
              height: 1.5,
            ),
          ),
          if (analysis.selectedDimensionHint != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: DashboardTheme.primaryLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                analysis.selectedDimensionHint!,
                style: const TextStyle(
                  fontSize: 12,
                  color: DashboardTheme.primary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SymbolLegend extends StatelessWidget {
  const _SymbolLegend({required this.config});

  final StyleLensConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: StyleSymbol.values.map((symbol) {
        final def = config.symbols[symbol]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(def.emoji, style: const TextStyle(fontSize: 16, height: 1.4)),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: DashboardTheme.muted,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(
                        text: '${def.label}: ',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: DashboardTheme.body,
                        ),
                      ),
                      TextSpan(text: def.shortDescription),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SymbolScoreGrid extends StatelessWidget {
  const _SymbolScoreGrid({
    required this.analysis,
    required this.config,
    required this.maxScore,
  });

  final StyleLensAnalysis analysis;
  final StyleLensConfig config;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 360
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: StyleSymbol.values.map((symbol) {
            return SizedBox(
              width: cardWidth,
              child: _SymbolScoreCard(
                symbol: symbol,
                definition: config.symbols[symbol]!,
                score: analysis.scoreFor(symbol),
                maxScore: maxScore,
                isDominant: analysis.isDominant(symbol),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SymbolScoreCard extends StatelessWidget {
  const _SymbolScoreCard({
    required this.symbol,
    required this.definition,
    required this.score,
    required this.maxScore,
    required this.isDominant,
  });

  final StyleSymbol symbol;
  final SymbolDefinition definition;
  final double score;
  final int maxScore;
  final bool isDominant;

  @override
  Widget build(BuildContext context) {
    final accent = DashboardTheme.parseHex(definition.color);
    final progress = (score / maxScore).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDominant ? accent.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDominant ? accent.withOpacity(0.35) : DashboardTheme.cardBorder,
        ),

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(definition.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  definition.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.heading,
                  ),
                ),
              ),
              Text(
                '${score.toStringAsFixed(1)} / $maxScore',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: DashboardTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DashboardTheme.cardHeading),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 14,
                    color: DashboardTheme.body,
                    height: 1.5,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: DashboardTheme.body,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
