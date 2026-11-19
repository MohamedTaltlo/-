import 'package:flutter_test/flutter_test.dart';
import 'package:mazraati/domain/ration_calculator.dart';

void main() {
  const engine = RationCalculator();

  const synthetic = RationFeed(
    name: 'علف مصطنع للاختبار فقط',
    asFedKg: 2,
    dryMatterPercent: 50,
    energyMjPerKgDm: 10,
    energySystem: 'ME',
    crudeProteinPercentDm: 12,
    ndfPercentDm: 40,
    maxDailyAsFedKg: 2.5,
    analysisSource: 'synthetic-test-data',
  );

  const fakeTargets = RationTargets(
    dryMatterKg: NumericRange(0.9, 1.1),
    energyMj: NumericRange(9, 11),
    energySystem: 'ME',
    proteinKg: NumericRange(0.1, 0.13),
    ndfKg: NumericRange(0.35, 0.45),
    source: 'اختبار مصطنع - ليس احتياجاً غذائياً حقيقياً',
    sourceKind: 'user',
  );

  test('accounts for as-fed versus dry-matter in a synthetic scenario', () {
    final a = engine.evaluate([synthetic], targets: fakeTargets);
    expect(a.asFedKg, 2);
    expect(a.dryMatter.value, closeTo(1, 1e-9));
    expect(a.energy.value, closeTo(10, 1e-9));
    expect(a.protein.value, closeTo(0.12, 1e-9));
    expect(a.ndf.value, closeTo(0.4, 1e-9));
    expect(a.allMetricsWithinRecordedRanges, true);
  });

  test('missing NDF remains unknown and cannot imply complete evaluation', () {
    final a = engine.evaluate([
      const RationFeed(
        name: 'اختبار مجهول الألياف',
        asFedKg: 2,
        dryMatterPercent: 50,
        energyMjPerKgDm: 10,
        energySystem: 'ME',
        crudeProteinPercentDm: 12,
        analysisSource: 'synthetic',
      ),
    ], targets: fakeTargets);
    expect(a.ndf.value, isNull);
    expect(a.ndf.state, RangeState.unknown);
    expect(a.allMetricsWithinRecordedRanges, false);
  });

  test('missing dry matter blocks dependent calculations', () {
    final a = engine.evaluate([
      const RationFeed(name: 'اختبار بدون DM', asFedKg: 1),
    ], targets: fakeTargets);
    expect(a.hasInvalidInputs, true);
    expect(a.dryMatter.value, isNull);
    expect(a.energy.value, isNull);
  });

  test('exceeding user limit flags the candidate as invalid', () {
    final a = engine.evaluate([
      const RationFeed(
        name: 'تجربة حد يومي',
        asFedKg: 3,
        maxDailyAsFedKg: 2,
        dryMatterPercent: 90,
        analysisSource: 'synthetic',
      ),
    ]);
    expect(a.hasInvalidInputs, true);
  });

  test('energy systems must match rather than mixing ME and other systems', () {
    final a = engine.evaluate([
      const RationFeed(
        name: 'اختبار نظام مختلف',
        asFedKg: 1,
        dryMatterPercent: 90,
        energyMjPerKgDm: 10,
        energySystem: 'DE',
        analysisSource: 'synthetic',
      ),
    ], targets: fakeTargets);
    expect(a.hasInvalidInputs, true);
    expect(a.energy.value, isNull);
  });

  test('below-target energy is not reported as balanced', () {
    final a = engine.evaluate([
      const RationFeed(
        name: 'اختبار نقص الطاقة',
        asFedKg: 1,
        dryMatterPercent: 50,
        energyMjPerKgDm: 10,
        energySystem: 'ME',
        crudeProteinPercentDm: 12,
        ndfPercentDm: 40,
        analysisSource: 'synthetic',
      ),
    ], targets: fakeTargets);
    expect(a.energy.state, RangeState.below);
    expect(a.allMetricsWithinRecordedRanges, false);
  });

  test('empty feed list is blocked', () {
    final a = engine.evaluate([], targets: fakeTargets);
    expect(a.hasInvalidInputs, true);
  });

  test('invalid target ranges are rejected', () {
    const invalid = RationTargets(
      dryMatterKg: NumericRange(2, 1),
      energyMj: NumericRange(9, 11),
      energySystem: 'ME',
      proteinKg: NumericRange(0.1, 0.13),
      ndfKg: NumericRange(0.35, 0.45),
      source: 'synthetic',
      sourceKind: 'user',
    );
    final a = engine.evaluate([synthetic], targets: invalid);
    expect(a.hasInvalidInputs, true);
    expect(a.dryMatter.state, RangeState.invalid);
  });
}
