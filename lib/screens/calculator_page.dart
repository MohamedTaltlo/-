import 'package:flutter/material.dart';
import '../data/farm_store.dart';
import '../domain/ration_calculator.dart';
import 'ui_helpers.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.store});
  final FarmStore store;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  List<Map<String, Object?>> animals = [];
  List<Map<String, Object?>> feeds = [];
  final Map<int, TextEditingController> quantities = {};
  int? animalId;
  Map<String, Object?>? selectedAnimal;
  RationTargets? targets;
  RationAssessment? result;
  List<RationFeed> evaluatedFeeds = [];
  List<Map<String, Object?>> evaluatedRows = [];
  String? blockingError;
  double? cost;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    for (final controller in quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> refresh() async {
    final a = await widget.store.animals();
    final f = await widget.store.feeds();
    for (final controller in quantities.values) {
      controller.dispose();
    }
    quantities.clear();
    for (final row in f) {
      quantities[row['id'] as int] = TextEditingController();
    }
    int? next = animalId;
    if (!a.any((row) => row['id'] == next)) {
      next = a.isEmpty ? null : a.first['id'] as int;
    }
    if (!mounted) return;
    setState(() {
      animals = a;
      feeds = f;
      animalId = next;
      selectedAnimal = a.where((row) => row['id'] == next).firstOrNull;
      result = null;
      blockingError = null;
    });
    await loadTargets();
  }

  Future<void> loadTargets() async {
    if (animalId == null) {
      if (mounted) setState(() => targets = null);
      return;
    }
    final row = await widget.store.target(animalId!);
    if (!mounted) return;
    RationTargets? t;
    if (row != null) {
      t = RationTargets(
        dryMatterKg: NumericRange(_num(row['dm_min']), _num(row['dm_max'])),
        energyMj: NumericRange(_num(row['energy_min']), _num(row['energy_max'])),
        proteinKg: NumericRange(_num(row['protein_min']), _num(row['protein_max'])),
        ndfKg: NumericRange(_num(row['ndf_min']), _num(row['ndf_max'])),
        energySystem: (row['energy_system'] ?? '').toString(),
        source: (row['source'] ?? '').toString(),
        sourceKind: (row['source_kind'] ?? 'user').toString(),
      );
    }
    setState(() {
      targets = t;
      result = null;
      blockingError = null;
    });
  }

  double? _num(Object? value) => (value as num?)?.toDouble();

  Future<void> editTarget() async {
    if (animalId == null || selectedAnimal == null) return;
    final saved = await widget.store.target(animalId!);
    const keys = [
      'dm_min', 'dm_max', 'energy_min', 'energy_max',
      'protein_min', 'protein_max', 'ndf_min', 'ndf_max',
    ];
    const labels = [
      'المادة الجافة - الأدنى (كغ)', 'المادة الجافة - الأعلى (كغ)',
      'الطاقة ME - الأدنى (MJ)', 'الطاقة ME - الأعلى (MJ)',
      'البروتين الخام - الأدنى (كغ)', 'البروتين الخام - الأعلى (كغ)',
      'الألياف NDF - الأدنى (كغ)', 'الألياف NDF - الأعلى (كغ)',
    ];
    final controllers = <String, TextEditingController>{};
    for (final key in keys) {
      controllers[key] = TextEditingController(
          text: saved?[key]?.toString() ?? '');
    }
    final source = TextEditingController(text: (saved?['source'] ?? '').toString());
    var kind = (saved?['source_kind'] ?? 'user').toString();
    final success = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, change) {
        return AlertDialog(
          title: const Text('الاحتياجات المستهدفة'),
          content: SizedBox(width: 450, child: SingleChildScrollView(child:
            Column(mainAxisSize: MainAxisSize.min, children: [
              notice('الأهداف ليست محسوبة تلقائياً. أدخل نطاقات لحالة الحيوان من مرجع موثق أو سجل أنها من المستخدم.'),
              Text('الحالة الحالية: ' + (selectedAnimal?['life_stage'] ?? '').toString()),
              const SizedBox(height: 10),
              for (var i = 0; i < keys.length; i++) ...[
                numberField(controllers[keys[i]]!, labels[i]),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'نوع مصدر الهدف', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('هدف أدخله المستخدم')),
                  DropdownMenuItem(value: 'reference', child: Text('من مرجع موثق — يحتاج مراجعة')),
                ],
                onChanged: (v) => change(() => kind = v ?? kind),
              ),
              const SizedBox(height: 10),
              stringField(source, 'تفاصيل المرجع/اسم المختص/الرابط *', maxLines: 2),
              const SizedBox(height: 8),
              notice('الطاقة المدخلة ME بوحدة MJ. ترك نطاق فارغ يعني لا يمكن تقييمه. لا تُفسر المطابقة وحدها كسلامة غذائية.'),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              bool valid = source.text.trim().isNotEmpty;
              for (final key in keys) {
                if (!validOptionalNumber(controllers[key]!.text)) valid = false;
              }
              for (var i = 0; i < keys.length; i += 2) {
                final lo = parseNumber(controllers[keys[i]]!.text);
                final hi = parseNumber(controllers[keys[i + 1]]!.text);
                if ((lo == null) != (hi == null) || (lo != null && hi != null && lo > hi)) {
                  valid = false;
                }
              }
              if (!valid) {
                message(context, 'أدخل المصدر ونطاقات صالحة (حد أدنى وأعلى معاً).');
                return;
              }
              final values = <String, Object?>{};
              for (final key in keys) {
                values[key] = parseNumber(controllers[key]!.text);
              }
              values.addAll({
                'energy_system': 'ME',
                'applicable_stage': selectedAnimal!['life_stage'],
                'source': source.text.trim(),
                'source_kind': kind,
                'reviewed_at': null,
              });
              try {
                await widget.store.saveTarget(animalId!, values);
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) message(context, 'تعذر حفظ الهدف: ' + error.toString());
              }
            }, child: const Text('حفظ')),
          ],
        );
      }),
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    source.dispose();
    if (success == true) loadTargets();
  }

  void calculate() {
    final chosen = <RationFeed>[];
    final rows = <Map<String, Object?>>[];
    String? error;
    double sumCost = 0;
    bool knownCost = true;

    if (selectedAnimal == null ||
        _num(selectedAnimal!['weight_kg']) == null ||
        _num(selectedAnimal!['weight_kg'])! <= 0) {
      error = 'اختر حيواناً بوزن صالح أولاً.';
    }

    for (final feed in feeds) {
      final id = feed['id'] as int;
      final typed = quantities[id]?.text.trim() ?? '';
      if (typed.isEmpty) continue;
      final qty = parseNumber(typed);
      if (qty == null || !qty.isFinite || qty < 0) {
        error = 'كمية غير صالحة للعلف: ' + (feed['name'] ?? '').toString();
        break;
      }
      if (qty == 0) continue;
      final stock = _num(feed['stock_kg']);
      if (stock != null && qty > stock) {
        error = 'كمية العلف تتجاوز المخزون المسجل: ' + (feed['name'] ?? '').toString();
        break;
      }
      final price = _num(feed['price_per_kg']);
      if (price == null) { knownCost = false; } else { sumCost += price * qty; }
      chosen.add(RationFeed(
        name: feed['name'].toString(),
        asFedKg: qty,
        dryMatterPercent: _num(feed['dm_percent']),
        energyMjPerKgDm: _num(feed['energy_mj_kg_dm']),
        energySystem: feed['energy_system']?.toString(),
        crudeProteinPercentDm: _num(feed['cp_percent_dm']),
        ndfPercentDm: _num(feed['ndf_percent_dm']),
        maxDailyAsFedKg: _num(feed['max_daily_kg']),
        analysisSource: (feed['source_type'] ?? '').toString(),
      ));
      rows.add(feed);
    }

    if (error != null) {
      setState(() {
        blockingError = error;
        result = null;
      });
      return;
    }
    final current = widget.store.target(animalId!);
    // Deliberately do not await this access: the current cached goals are
    // compared below; reloading targets happens on animal change/save.
    current.ignore();
    final assessment = const RationCalculator().evaluate(chosen, targets: targets);
    setState(() {
      blockingError = null;
      evaluatedFeeds = chosen;
      evaluatedRows = rows;
      result = assessment;
      cost = knownCost ? sumCost : null;
    });
  }

  String stateLabel(RangeState state) {
    switch (state) {
      case RangeState.below: return 'أقل من النطاق';
      case RangeState.within: return 'ضمن النطاق المُدخل';
      case RangeState.above: return 'أعلى من النطاق';
      case RangeState.invalid: return 'هدف غير صالح';
      case RangeState.unknown: return 'لا يمكن التقييم';
    }
  }

  Widget metric(String title, MetricAssessment metric, String unit) {
    final state = metric.state;
    final color = state == RangeState.within ? Colors.green :
        (state == RangeState.above || state == RangeState.below) ? Colors.orange : null;
    return Card(child: ListTile(
      title: Text(title),
      subtitle: Text('الهدف: ' + number(metric.range?.minimum) + ' – ' +
          number(metric.range?.maximum) + ' ' + unit),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(number(metric.value) + ' ' + unit,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(stateLabel(state), style: const TextStyle(fontSize: 11)),
        ]),
    ));
  }

  Future<void> save() async {
    if (animalId == null || result == null || result!.hasInvalidInputs ||
        evaluatedFeeds.isEmpty) return;
    final items = <Map<String, Object?>>[];
    for (var i = 0; i < evaluatedFeeds.length; i++) {
      final f = evaluatedFeeds[i];
      items.add({
        'feed_name': f.name,
        'as_fed_kg': f.asFedKg,
        'dm_percent': f.dryMatterPercent,
        'energy_mj_kg_dm': f.energyMjPerKgDm,
        'cp_percent_dm': f.crudeProteinPercentDm,
        'ndf_percent_dm': f.ndfPercentDm,
      });
    }
    try {
      await widget.store.saveRation(
        animalId: animalId!,
        asFedKg: result!.asFedKg,
        dmKg: result!.dryMatter.value,
        energyMj: result!.energy.value,
        proteinKg: result!.protein.value,
        ndfKg: result!.ndf.value,
        warnings: result!.warnings,
        items: items,
      );
      if (mounted) message(context, 'حُفظت الحصة ونتائجها مع التحذيرات في السجل المحلي.');
    } catch (error) {
      if (mounted) message(context, 'فشل الحفظ: ' + error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12),
    children: [
      notice('هذه الحاسبة أداة إرشادية فقط. يلزم مراجعة طبيب بيطري أو مختص تغذية مجترات قبل اعتماد أي حصة. لا يوجد مقترح تلقائي دون مراجع وحدود موثقة.'),
      if (animals.isEmpty) notice('أضف حيواناً في تبويب الحيوانات أولاً.'),
      if (feeds.isEmpty) notice('أضف علفاً وتحليله في تبويب الأعلاف أولاً.'),
      if (animals.isNotEmpty) DropdownButtonFormField<int>(
        initialValue: animalId,
        decoration: const InputDecoration(labelText: 'اختر الحيوان', border: OutlineInputBorder()),
        items: animals.map((a) => DropdownMenuItem<int>(
          value: a['id'] as int,
          child: Text((a['name'] ?? '').toString() + ' • ' + (a['life_stage'] ?? '').toString()),
        )).toList(),
        onChanged: (id) {
          setState(() {
            animalId = id;
            selectedAnimal = animals.where((a) => a['id'] == id).firstOrNull;
            result = null;
          });
          loadTargets();
        },
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: animalId == null ? null : editTarget,
        icon: const Icon(Icons.tune), label: const Text('تسجيل أو تعديل الاحتياجات المستهدفة')),
      if (targets != null) notice('مصدر الاحتياجات: ' + targets!.source +
          '\nنوع المصدر: ' + (targets!.sourceKind == 'reference' ? 'مرجع سجله المستخدم (غير متحقق داخل التطبيق)' : 'إدخال المستخدم')),
      const SizedBox(height: 8),
      Text('مكونات الحصة اليومية', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      for (final feed in feeds)
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((feed['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text('DM ' + number(_num(feed['dm_percent'])) + '%  •  ME ' +
                number(_num(feed['energy_mj_kg_dm'])) + ' MJ/kg DM  •  CP ' +
                number(_num(feed['cp_percent_dm'])) + '%  •  NDF ' +
                number(_num(feed['ndf_percent_dm'])) + '%'),
            const SizedBox(height: 8),
            numberField(quantities[feed['id'] as int]!, 'الكمية المقدمة (كغ كما يُقدّم)'),
            if (_num(feed['max_daily_kg']) != null)
              Text('الحد المُدخل: ' + number(_num(feed['max_daily_kg'])) + ' كغ/يوم'),
          ]),
        )),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: animals.isEmpty || feeds.isEmpty ? null : calculate,
        icon: const Icon(Icons.calculate), label: const Text('احسب الحصة'),
      ),
      if (blockingError != null) notice(blockingError!, icon: Icons.error_outline),
      if (result != null) ...[
        const SizedBox(height: 14),
        Text('نتيجة الحساب', style: Theme.of(context).textTheme.titleLarge),
        metric('المادة الجافة', result!.dryMatter, 'كغ'),
        metric('الطاقة الأيضية ME', result!.energy, 'MJ'),
        metric('البروتين الخام', result!.protein, 'كغ'),
        metric('الألياف NDF', result!.ndf, 'كغ'),
        Card(child: ListTile(
          title: const Text('إجمالي وزن الأعلاف كما تُقدّم'),
          trailing: Text(number(result!.asFedKg) + ' كغ'),
        )),
        Card(child: ListTile(
          title: const Text('التكلفة اليومية (العملة التي سجلتها)'),
          trailing: Text(number(cost)),
        )),
        for (final warning in result!.warnings) notice(warning, icon: Icons.warning_amber),
        notice('مطابقة القيم المدخلة لا تعني أن الحصة متوازنة أو آمنة. الماء والمعادن والفيتامينات وعوامل الحالة الصحية خارج هذا التقييم.'),
        FilledButton.icon(
          onPressed: result!.hasInvalidInputs || evaluatedFeeds.isEmpty ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ هذه الحصة في السجل'),
        ),
      ],
    ],
  );
}
