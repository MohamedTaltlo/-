/// Pure, deterministic nutrient accounting. No built-in nutritional recommendations.
/// All test data and user-entered values are explicitly non-prescriptive.
class RationFeed {
  const RationFeed({
    required this.name,
    required this.asFedKg,
    this.dryMatterPercent,
    this.energyMjPerKgDm,
    this.energySystem,
    this.crudeProteinPercentDm,
    this.ndfPercentDm,
    this.maxDailyAsFedKg,
    this.analysisSource = '',
  });

  final String name;
  final double asFedKg;
  final double? dryMatterPercent;
  final double? energyMjPerKgDm;
  /// ME (metabolizable energy) or another explicit system.
  final String? energySystem;
  final double? crudeProteinPercentDm;
  final double? ndfPercentDm;
  final double? maxDailyAsFedKg;
  final String analysisSource;
}

class NumericRange {
  const NumericRange(this.minimum, this.maximum);
  final double? minimum;
  final double? maximum;

  bool get isComplete => minimum != null && maximum != null;
  bool get isValid =>
      isComplete &&
      minimum!.isFinite &&
      maximum!.isFinite &&
      minimum! >= 0 &&
      minimum! <= maximum!;
}

class RationTargets {
  const RationTargets({
    required this.dryMatterKg,
    required this.energyMj,
    required this.energySystem,
    required this.proteinKg,
    required this.ndfKg,
    required this.source,
    required this.sourceKind,
  });

  final NumericRange dryMatterKg;
  final NumericRange energyMj;
  final String energySystem;
  final NumericRange proteinKg;
  final NumericRange ndfKg;
  final String source;
  /// 'reference' or 'user'. Neither is independently verified by the app.
  final String sourceKind;
}

enum RangeState { below, within, above, unknown, invalid }

class MetricAssessment {
  const MetricAssessment(this.value, this.range, this.state);
  final double? value;
  final NumericRange? range;
  final RangeState state;
}

class RationAssessment {
  const RationAssessment({
    required this.asFedKg,
    required this.dryMatter,
    required this.energy,
    required this.protein,
    required this.ndf,
    required this.warnings,
    required this.hasInvalidInputs,
  });

  final double asFedKg;
  final MetricAssessment dryMatter;
  final MetricAssessment energy;
  final MetricAssessment protein;
  final MetricAssessment ndf;
  final List<String> warnings;
  final bool hasInvalidInputs;

  bool get allMetricsWithinRecordedRanges =>
      !hasInvalidInputs &&
      dryMatter.state == RangeState.within &&
      energy.state == RangeState.within &&
      protein.state == RangeState.within &&
      ndf.state == RangeState.within;
}

class RationCalculator {
  const RationCalculator();

  RationAssessment evaluate(
    List<RationFeed> feeds, {
    RationTargets? targets,
  }) {
    final warnings = <String>[];
    var invalid = feeds.isEmpty;
    if (feeds.isEmpty) warnings.add('لم تُضف أي أعلاف للحصة.');

    var asFedKg = 0.0;
    double? dmKg = 0;
    double? energyMj = 0;
    double? proteinKg = 0;
    double? ndfKg = 0;
    String? expectedEnergySystem = targets?.energySystem;

    for (final feed in feeds) {
      if (!feed.asFedKg.isFinite || feed.asFedKg <= 0) {
        invalid = true;
        warnings.add('كمية غير صالحة للعلف: ${feed.name}.');
        continue;
      }
      asFedKg += feed.asFedKg;
      if (feed.maxDailyAsFedKg != null &&
          (!feed.maxDailyAsFedKg!.isFinite ||
              feed.maxDailyAsFedKg! < 0 ||
              feed.asFedKg > feed.maxDailyAsFedKg! + 0.0000001)) {
        invalid = true;
        warnings.add('تجاوزت الكمية الحد الذي أدخلته للعلف: ${feed.name}.');
      }
      if (feed.analysisSource.trim().isEmpty ||
          feed.analysisSource == 'غير متوفر') {
        warnings.add('مصدر تحليل العلف غير مسجل: ${feed.name}.');
      }
      final dm = feed.dryMatterPercent;
      if (dm == null || !dm.isFinite || dm <= 0 || dm > 100) {
        invalid = true;
        dmKg = null;
        energyMj = null;
        proteinKg = null;
        ndfKg = null;
        warnings.add('المادة الجافة مفقودة أو غير صالحة: ${feed.name}.');
        continue;
      }
      final portionDm = feed.asFedKg * dm / 100;
      if (dmKg != null) dmKg += portionDm;
      if (feed.energyMjPerKgDm != null &&
          expectedEnergySystem == null &&
          feed.energySystem != null &&
          feed.energySystem!.trim().isNotEmpty) {
        expectedEnergySystem = feed.energySystem;
      }
      if (feed.energyMjPerKgDm != null &&
          (feed.energySystem == null ||
              feed.energySystem!.trim().isEmpty ||
              feed.energySystem != expectedEnergySystem)) {
        invalid = true;
        energyMj = null;
        warnings.add('نظام الطاقة مفقود أو غير مطابق للعلف: ${feed.name}.');
      }
      if (feed.energyMjPerKgDm == null ||
          !feed.energyMjPerKgDm!.isFinite ||
          feed.energyMjPerKgDm! < 0) {
        energyMj = null;
        warnings.add('طاقة العلف غير متوفرة: ${feed.name}.');
      } else if (energyMj != null) {
        energyMj += portionDm * feed.energyMjPerKgDm!;
      }

      final cp = feed.crudeProteinPercentDm;
      if (cp == null || !cp.isFinite || cp < 0 || cp > 100) {
        proteinKg = null;
        warnings.add('البروتين الخام غير متوفر: ${feed.name}.');
      } else if (proteinKg != null) {
        proteinKg += portionDm * cp / 100;
      }

      final ndf = feed.ndfPercentDm;
      if (ndf == null || !ndf.isFinite || ndf < 0 || ndf > 100) {
        ndfKg = null;
        warnings.add('NDF غير متوفر: ${feed.name}.');
      } else if (ndfKg != null) {
        ndfKg += portionDm * ndf / 100;
      }
    }

    if (targets == null) {
      warnings.add('لا يوجد هدف غذائي مدخل لهذه الحصة.');
    } else {
      if (targets.source.trim().isEmpty) {
        warnings.add('مصدر الاحتياجات الغذائية غير محدد.');
      } else if (targets.sourceKind != 'reference') {
        warnings.add('الاحتياجات أدخلها المستخدم وليست مرجعاً علمياً معتمداً.');
      }
    }
    if (targets != null) {
      for (final pair in <MapEntry<String, NumericRange>>[
        MapEntry('المادة الجافة', targets.dryMatterKg),
        MapEntry('الطاقة', targets.energyMj),
        MapEntry('البروتين', targets.proteinKg),
        MapEntry('الألياف NDF', targets.ndfKg),
      ]) {
        if (pair.value.isComplete && !pair.value.isValid) {
          invalid = true;
          warnings.add('نطاق الهدف غير صالح: ${pair.key}.');
        } else if (!pair.value.isComplete) {
          warnings.add('نطاق الهدف غير مكتمل: ${pair.key}.');
        }
      }
    }
    warnings.add('الماء والمعادن والفيتامينات لم تُقيّم: يلزم تحليل ومراجع مناسبة.');
    return RationAssessment(
      asFedKg: asFedKg,
      dryMatter: _metric(dmKg, targets?.dryMatterKg),
      energy: _metric(energyMj, targets?.energyMj),
      protein: _metric(proteinKg, targets?.proteinKg),
      ndf: _metric(ndfKg, targets?.ndfKg),
      warnings: warnings,
      hasInvalidInputs: invalid,
    );
  }

  MetricAssessment _metric(double? value, NumericRange? range) {
    if (range != null && range.isComplete && !range.isValid) {
      return MetricAssessment(value, range, RangeState.invalid);
    }
    if (value == null || range == null || !range.isValid) {
      return MetricAssessment(value, range, RangeState.unknown);
    }
    if (value < range.minimum! - 0.0000001) {
      return MetricAssessment(value, range, RangeState.below);
    }
    if (value > range.maximum! + 0.0000001) {
      return MetricAssessment(value, range, RangeState.above);
    }
    return MetricAssessment(value, range, RangeState.within);
  }
}
