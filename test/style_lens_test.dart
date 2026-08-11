import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_capability_dashboard/data/defaults.dart';
import 'package:ai_capability_dashboard/data/style_lens_config.dart';
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

    test('paladin-heavy profile makes paladin dominant and warrior weakest', () {
      final dimensions = defaultDashboardData.dimensions
          .map(
            (d) => d.copyWith(
              score: switch (d.id) {
                4 || 5 => 5.0,
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

      expect(analysis.scoreFor(StyleSymbol.paladin), greaterThan(3.5));
      expect(
        analysis.scoreFor(StyleSymbol.warrior),
        lessThan(analysis.scoreFor(StyleSymbol.paladin)),
      );
      expect(analysis.dominantSymbols, contains(StyleSymbol.paladin));
      expect(analysis.weakestSymbols, contains(StyleSymbol.warrior));
      expect(analysis.headline, contains('Paladin'));
    });

    test('artificer and commander blend when scores are within threshold', () {
      final dimensions = defaultDashboardData.dimensions
          .map(
            (d) => d.copyWith(
              score: switch (d.id) {
                2 || 3 => 5.0,
                5 => 4.5,
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

      final artificer = analysis.scoreFor(StyleSymbol.artificer);
      final commander = analysis.scoreFor(StyleSymbol.commander);
      expect((artificer - commander).abs(), lessThanOrEqualTo(styleLensConfig.blendThreshold));
      expect(analysis.dominantSymbols, contains(StyleSymbol.artificer));
      expect(analysis.dominantSymbols, contains(StyleSymbol.commander));
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
      expect(analysis.selectedDimensionHint, contains('Prompt Engineering'));
      expect(analysis.selectedDimensionHint, contains('Warrior'));
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
      expect(find.textContaining('Warrior'), findsWidgets);
      expect(find.textContaining('Paladin'), findsWidgets);
      expect(find.textContaining('Artificer'), findsWidgets);
      expect(find.textContaining('Commander'), findsWidgets);

      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });
}
