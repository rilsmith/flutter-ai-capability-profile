import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/data/style_lens_config.dart';
import 'package:ai_capability_dashboard/models/dimension.dart';
import 'package:ai_capability_dashboard/utils/style_lens.dart';
import 'package:ai_capability_dashboard/widgets/style_lens_panel.dart';

void main() {
  final tiers = defaultDashboardData.tiers;
  const maxScore = 5;

  group('weight integrity', () {
    test('each dimension weight map sums to 1.0', () {
      for (final entry in styleLensConfig.dimensionWeights.entries) {
        expect(
          entry.value.total,
          closeTo(1.0, 0.0001),
          reason: 'dimension id ${entry.key}',
        );
      }
    });
  });

  group('computeStyleLens', () {
    test('balanced profile yields equal symbol scores', () {
      final dimensions = defaultDashboardData.dimensions
          .map((d) => d.copyWith(score: 3.0))
          .toList();

      final analysis = computeStyleLens(
        dimensions,
        tiers: tiers,
        maxScore: maxScore,
      );

      for (final symbol in StyleSymbol.values) {
        expect(analysis.scoreFor(symbol), 3.0);
      }
      expect(analysis.headline, contains('Balanced'));
      expect(analysis.dominantSymbols.length, StyleSymbol.values.length);
    });

    test('shield-heavy profile makes shield dominant and sword weakest', () {
      final dimensions = defaultDashboardData.dimensions
          .map(
            (d) => d.copyWith(
              score: switch (d.id) {
                4 || 9 => 5.0,
                _ => 2.0,
              },
            ),
          )
          .toList();

      final analysis = computeStyleLens(
        dimensions,
        tiers: tiers,
        maxScore: maxScore,
      );

      expect(analysis.scoreFor(StyleSymbol.shield), greaterThan(3.5));
      expect(
        analysis.scoreFor(StyleSymbol.sword),
        lessThan(analysis.scoreFor(StyleSymbol.shield)),
      );
      expect(analysis.dominantSymbols, contains(StyleSymbol.shield));
      expect(analysis.weakestSymbols, contains(StyleSymbol.sword));
      expect(analysis.headline, contains('Shield'));
    });

    test('cog and banner blend when scores are within threshold', () {
      final dimensions = defaultDashboardData.dimensions
          .map(
            (d) => d.copyWith(
              score: switch (d.id) {
                2 || 3 => 5.0,
                6 || 8 || 7 => 4.5,
                _ => 3.0,
              },
            ),
          )
          .toList();

      final analysis = computeStyleLens(
        dimensions,
        tiers: tiers,
        maxScore: maxScore,
      );

      final cog = analysis.scoreFor(StyleSymbol.cog);
      final banner = analysis.scoreFor(StyleSymbol.banner);
      expect((cog - banner).abs(), lessThanOrEqualTo(styleLensConfig.blendThreshold));
      expect(analysis.dominantSymbols, contains(StyleSymbol.cog));
      expect(analysis.dominantSymbols, contains(StyleSymbol.banner));
      expect(analysis.headline, contains('&'));
    });

    test('selected dimension hint names top contributing symbol', () {
      final dimensions = defaultDashboardData.dimensions;

      final analysis = computeStyleLens(
        dimensions,
        tiers: tiers,
        maxScore: maxScore,
        selectedDimensionId: 1,
      );

      expect(analysis.selectedDimensionHint, isNotNull);
      expect(analysis.selectedDimensionHint, contains('Human-Agent Interaction'));
      expect(analysis.selectedDimensionHint, contains('Sword'));
      expect(analysis.selectedDimensionHint, contains('75%'));
    });
  });

  group('StyleLensPanel', () {
    testWidgets('renders title, scores, and suggested focus', (tester) async {
      final dimensions = defaultDashboardData.dimensions;
      final analysis = computeStyleLens(
        dimensions,
        tiers: tiers,
        maxScore: maxScore,
      );

      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StyleLensPanel(
                analysis: analysis,
                config: styleLensConfig,
                maxScore: maxScore,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Engineering Style Lens'), findsOneWidget);
      expect(find.text('Suggested focus'), findsOneWidget);
      expect(find.textContaining('Sword'), findsWidgets);
      expect(find.textContaining('Shield'), findsWidgets);
      expect(find.textContaining('Cog'), findsWidgets);
      expect(find.textContaining('Banner'), findsWidgets);

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
