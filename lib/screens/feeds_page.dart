import 'package:flutter/material.dart';
import '../data/farm_store.dart';
import 'ui_helpers.dart';

class FeedsPage extends StatefulWidget {
  const FeedsPage({super.key, required this.store});
  final FarmStore store;

  @override
  State<FeedsPage> createState() => _FeedsPageState();
}

class _FeedsPageState extends State<FeedsPage> {
  List<Map<String, Object?>> records = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final data = await widget.store.feeds();
    if (mounted) setState(() => records = data);
  }

  Future<void> add([Map<String, Object?>? existing]) async {
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final category = TextEditingController(text: existing?['category']?.toString() ?? '');
    final stock = TextEditingController(text: existing?['stock_kg']?.toString() ?? '');
    final price = TextEditingController(text: existing?['price_per_kg']?.toString() ?? '');
    final dm = TextEditingController(text: existing?['dm_percent']?.toString() ?? '');
    final energy = TextEditingController(text: existing?['energy_mj_kg_dm']?.toString() ?? '');
    final cp = TextEditingController(text: existing?['cp_percent_dm']?.toString() ?? '');
    final ndf = TextEditingController(text: existing?['ndf_percent_dm']?.toString() ?? '');
    final dailyMax = TextEditingController(text: existing?['max_daily_kg']?.toString() ?? '');
    final sourceNote = TextEditingController(text: existing?['source_note']?.toString() ?? '');
    final analyzedAt = TextEditingController(text: existing?['analyzed_at']?.toString() ?? '');
    var sourceType = (existing?['source_type'] ?? 'غير متوفر').toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, change) {
        return AlertDialog(
          title: Text(existing == null ? 'إضافة علف وتحليله' : 'تعديل العلف وتحليله'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                notice('أدخل فقط القيم المتحققة. أي خانة فارغة تبقى مجهولة ولا تُعوض بقيمة افتراضية.'),
                stringField(name, 'اسم العلف *'),
                const SizedBox(height: 10),
                stringField(category, 'التصنيف (تبن، مركز، ... )'),
                const SizedBox(height: 10),
                numberField(stock, 'الكمية المتاحة (كغ، اختياري)'),
                const SizedBox(height: 10),
                numberField(price, 'السعر لكل كغ كما يُقدّم (اختياري)'),
                const Divider(height: 28),
                numberField(dm, 'المادة الجافة DM (%)'),
                const SizedBox(height: 10),
                numberField(energy, 'الطاقة الأيضية ME (MJ/كغ مادة جافة)'),
                const SizedBox(height: 10),
                numberField(cp, 'البروتين الخام CP (% من المادة الجافة)'),
                const SizedBox(height: 10),
                numberField(ndf, 'الألياف NDF (% من المادة الجافة)'),
                const SizedBox(height: 10),
                numberField(dailyMax, 'حدك المدخل لكمية العلف اليومية (كغ)'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: sourceType,
                  decoration: const InputDecoration(labelText: 'مصدر تحليل العلف', border: OutlineInputBorder()),
                  items: ['غير متوفر', 'مختبر', 'ملصق مصنع', 'مرجع منشور', 'إدخال المستخدم']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => change(() => sourceType = v ?? sourceType),
                ),
                const SizedBox(height: 10),
                stringField(sourceNote, 'اسم المختبر/المرجع/ملاحظات'),
                const SizedBox(height: 10),
                stringField(analyzedAt, 'تاريخ التحليل YYYY-MM-DD'),
                const SizedBox(height: 10),
                notice('الحد اليومي الذي تسجله قيد منك وليس توصية علمية. تُحسب الطاقة هنا بنظام ME فقط.'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              final percentages = [dm.text, cp.text, ndf.text];
              final values = [stock.text, price.text, energy.text, dailyMax.text];
              if (name.text.trim().isEmpty ||
                  percentages.any((s) => !validOptionalNumber(s, max: 100)) ||
                  values.any((s) => !validOptionalNumber(s)) ||
                  (dm.text.trim().isNotEmpty && (parseNumber(dm.text) ?? 0) <= 0) ||
                  (analyzedAt.text.trim().isNotEmpty &&
                      DateTime.tryParse(analyzedAt.text.trim()) == null) ||
                  (energy.text.trim().isNotEmpty &&
                      sourceType == 'غير متوفر')) {
                message(context, 'تحقق من الأرقام والتاريخ والمصدر؛ الطاقة تتطلب تحديد مصدر التحليل.');
                return;
              }
              try {
                final feedData = <String, Object?>{
                  'name': name.text.trim(),
                  'category': category.text.trim().isEmpty ? 'غير مصنف' : category.text.trim(),
                  'stock_kg': parseNumber(stock.text),
                  'price_per_kg': parseNumber(price.text),
                };
                final analysisData = <String, Object?>{
                  'dm_percent': parseNumber(dm.text),
                  'energy_mj_kg_dm': parseNumber(energy.text),
                  'energy_system': energy.text.trim().isEmpty ? null : 'ME',
                  'cp_percent_dm': parseNumber(cp.text),
                  'ndf_percent_dm': parseNumber(ndf.text),
                  'max_daily_kg': parseNumber(dailyMax.text),
                  'source_type': sourceType,
                  'source_note': sourceNote.text.trim(),
                  'analyzed_at': analyzedAt.text.trim().isEmpty ? null : analyzedAt.text.trim(),
                };
                if (existing == null) {
                  await widget.store.addFeed(feedData, analysisData);
                } else {
                  await widget.store.updateFeed(existing['id'] as int, feedData, analysisData);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) message(context, 'تعذر حفظ العلف: ' + error.toString());
              }
            }, child: const Text('حفظ')),
          ],
        );
      }),
    );
    name.dispose(); category.dispose(); stock.dispose(); price.dispose();
    dm.dispose(); energy.dispose(); cp.dispose(); ndf.dispose(); dailyMax.dispose();
    sourceNote.dispose(); analyzedAt.dispose();
    if (saved == true) refresh();
  }

  Future<void> remove(Map<String, Object?> feed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العلف؟'),
        content: const Text('سيُحذف التحليل المرتبط بهذا العلف، لكن نسخ البيانات المحفوظة في سجل الحصص ستبقى.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteFeed(feed['id'] as int);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Text('مكتبة الأعلاف: ' + records.length.toString(),
            style: Theme.of(context).textTheme.titleMedium)),
        FilledButton.icon(onPressed: () => add(), icon: const Icon(Icons.add), label: const Text('علف جديد')),
      ]),
    ),
    Expanded(child: records.isEmpty
      ? const Center(child: Text('أضف أعلاف مزرعتك مع تحليلها ومصدر التحليل.'))
      : ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, i) {
            final f = records[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.grass)),
                title: Text((f['name'] ?? '').toString()),
                subtitle: Text(
                  (f['category'] ?? '').toString() +
                  '\nDM: ' + number(f['dm_percent'] as double?) + '% • CP: ' +
                  number(f['cp_percent_dm'] as double?) + '% • NDF: ' +
                  number(f['ndf_percent_dm'] as double?) + '%' +
                  '\nME: ' + number(f['energy_mj_kg_dm'] as double?) + ' MJ/kg DM' +
                  '\nالمصدر: ' + (f['source_type'] ?? 'غير متوفر').toString(),
                ),
                isThreeLine: true,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'تعديل العلف',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => add(f),
                  ),
                  IconButton(
                    tooltip: 'حذف العلف',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => remove(f),
                  ),
                ]),
              ),
            );
          },
        )),
  ]);
}
