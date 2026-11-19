import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/farm_store.dart';
import 'ui_helpers.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.store});
  final FarmStore store;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, Object?>> entries = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final rows = await widget.store.rationHistory();
    if (mounted) setState(() => entries = rows);
  }

  double? _n(Object? x) => (x as num?)?.toDouble();

  Future<void> showEntry(Map<String, Object?> r) async {
    final items = await widget.store.rationItems(r['id'] as int);
    if (!mounted) return;
    final lines = <String>[
      'مزرعتي | سجل حصة تغذية (إرشادي)',
      'الحيوان: ' + (r['animal_name'] ?? '').toString(),
      'التاريخ: ' + (r['created_at'] ?? '').toString(),
      'كما يُقدم: ' + number(_n(r['as_fed_kg'])) + ' كغ',
      'المادة الجافة: ' + number(_n(r['dm_kg'])) + ' كغ',
      'الطاقة ME: ' + number(_n(r['energy_mj'])) + ' MJ',
      'البروتين الخام: ' + number(_n(r['protein_kg'])) + ' كغ',
      'الألياف NDF: ' + number(_n(r['ndf_kg'])) + ' كغ',
      'الأعلاف:',
      for (final item in items)
        '- ' + (item['feed_name'] ?? '').toString() +
          ': ' + number(_n(item['as_fed_kg'])) + ' كغ كما يُقدم',
      'التحذيرات:',
      (r['warnings'] ?? '').toString(),
      'يلزم مراجعة مختص تغذية مجترات قبل اعتماد الحصة.',
    ];
    final report = lines.join('\n');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الحصة'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(child: SelectableText(report)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (context.mounted) message(context, 'تم نسخ التقرير');
            },
            icon: const Icon(Icons.copy), label: const Text('نسخ التقرير'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> remove(Map<String, Object?> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحصة؟'),
        content: const Text('سيتم حذف هذا السجل ومكوناته نهائياً من الهاتف.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteRation(r['id'] as int);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12),
      child: notice('الحصص محفوظة محلياً على هذا الهاتف. عند حذف التطبيق قد تضيع البيانات؛ النسخ الاحتياطي والاستعادة ليستا متاحتين بعد.'),
    ),
    Expanded(child: entries.isEmpty
      ? const Center(child: Text('ما في حصص محفوظة بعد.'))
      : ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: ListTile(
                onTap: () => showEntry(entry),
                leading: const Icon(Icons.receipt_long),
                title: Text((entry['animal_name'] ?? '').toString()),
                subtitle: Text(
                  (entry['created_at'] ?? '').toString().split('T').first +
                  '\nكما يُقدّم: ' + number(_n(entry['as_fed_kg'])) +
                  ' كغ • مادة جافة: ' + number(_n(entry['dm_kg'])) + ' كغ',
                ),
                isThreeLine: true,
                trailing: IconButton(
                  onPressed: () => remove(entry),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف السجل',
                ),
              ),
            );
          },
        )),
  ]);
}
