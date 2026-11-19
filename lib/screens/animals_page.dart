import 'package:flutter/material.dart';
import '../data/farm_store.dart';
import 'ui_helpers.dart';

class AnimalsPage extends StatefulWidget {
  const AnimalsPage({super.key, required this.store});
  final FarmStore store;

  @override
  State<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends State<AnimalsPage> {
  List<Map<String, Object?>> animals = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final data = await widget.store.animals();
    if (mounted) setState(() { animals = data; loading = false; });
  }

  Future<void> add() async {
    final name = TextEditingController();
    final tag = TextEditingController();
    final weight = TextEditingController();
    final birth = TextEditingController();
    final pregnancy = TextEditingController();
    final breeding = TextEditingController();
    final milk = TextEditingController();
    final kids = TextEditingController();
    final bcs = TextEditingController();
    String sex = 'أنثى';
    String stage = 'صيانة';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, change) {
        return AlertDialog(
          title: const Text('إضافة حيوان'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                stringField(tag, 'رقم الحيوان *'),
                const SizedBox(height: 10),
                stringField(name, 'اسم الحيوان *'),
                const SizedBox(height: 10),
                numberField(weight, 'الوزن الحالي (كغ) *'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: sex,
                  decoration: const InputDecoration(labelText: 'الجنس', border: OutlineInputBorder()),
                  items: ['أنثى', 'ذكر'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => change(() => sex = v ?? sex),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: stage,
                  decoration: const InputDecoration(labelText: 'الحالة', border: OutlineInputBorder()),
                  items: ['نمو', 'صيانة', 'تسمين', 'حامل', 'مرضع', 'ذكر للتربية', 'أخرى']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => change(() => stage = v ?? stage),
                ),
                const SizedBox(height: 10),
                stringField(birth, 'تاريخ الميلاد YYYY-MM-DD (اختياري)'),
                const SizedBox(height: 10),
                if (stage == 'حامل') ...[
                  stringField(pregnancy, 'مرحلة الحمل (وصف، اختياري)'),
                  const SizedBox(height: 10),
                  stringField(breeding, 'تاريخ التلقيح YYYY-MM-DD'),
                  const SizedBox(height: 10),
                ],
                if (stage == 'مرضع') ...[
                  numberField(milk, 'الحليب اليومي (كغ/يوم)'),
                  const SizedBox(height: 10),
                  numberField(kids, 'عدد الجداء الراضعة'),
                  const SizedBox(height: 10),
                ],
                numberField(bcs, 'حالة الجسم BCS (مقياس 1–5 فقط)'),
                const SizedBox(height: 10),
                notice('قيمة BCS اختيارية، وتُحفظ فقط على مقياس 1–5. تاريخ قياس الوزن يُسجل عند الإضافة.'),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () async {
              final w = parseNumber(weight.text);
              final b = parseNumber(bcs.text);
              final m = parseNumber(milk.text);
              final k = parseNumber(kids.text);
              final birthDate = birth.text.trim();
              final bred = breeding.text.trim();
              if (tag.text.trim().isEmpty || name.text.trim().isEmpty ||
                  w == null || !w.isFinite || w <= 0 ||
                  !validOptionalNumber(bcs.text, min: 1, max: 5) ||
                  !validOptionalNumber(milk.text) ||
                  !validOptionalNumber(kids.text) ||
                  (k != null && k != k.roundToDouble()) ||
                  (birthDate.isNotEmpty && DateTime.tryParse(birthDate) == null) ||
                  (bred.isNotEmpty && DateTime.tryParse(bred) == null)) {
                message(context, 'تحقق من البيانات: الوزن موجب، والتواريخ YYYY-MM-DD، وBCS من 1 إلى 5.');
                return;
              }
              try {
                final id = await widget.store.addAnimal({
                  'identifier': tag.text.trim(),
                  'name': name.text.trim(),
                  'sex': sex,
                  'life_stage': stage,
                  'weight_kg': w,
                  'birth_date': birthDate.isEmpty ? null : birthDate,
                  'measured_at': DateTime.now().toIso8601String(),
                  'created_at': DateTime.now().toIso8601String(),
                });
                await widget.store.saveProfile(id, {
                  'pregnancy_stage': pregnancy.text.trim().isEmpty ? null : pregnancy.text.trim(),
                  'breeding_date': bred.isEmpty ? null : bred,
                  'daily_milk_kg': m,
                  'suckling_kids': k?.toInt(),
                  'bcs_value': b,
                  'bcs_scale': b == null ? null : '1-5',
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) message(context, 'تعذر الحفظ: ' + error.toString());
              }
            }, child: const Text('حفظ')),
          ],
        );
      }),
    );
    name.dispose(); tag.dispose(); weight.dispose(); birth.dispose(); pregnancy.dispose();
    breeding.dispose(); milk.dispose(); kids.dispose(); bcs.dispose();
    if (saved == true) refresh();
  }

  Future<void> remove(Map<String, Object?> animal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحيوان؟'),
        content: const Text('سيتم حذف الملف التغذوي والأهداف والحصص المسجلة لهذا الحيوان أيضاً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.deleteAnimal(animal['id'] as int);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Expanded(child: Text('عدد الحيوانات: ' + animals.length.toString(),
            style: Theme.of(context).textTheme.titleMedium)),
        FilledButton.icon(onPressed: add, icon: const Icon(Icons.add),
            label: const Text('حيوان جديد')),
      ]),
    ),
    Expanded(child: loading
      ? const Center(child: CircularProgressIndicator())
      : animals.isEmpty
        ? const Center(child: Text('لا يوجد حيوانات بعد. ابدأ بإضافة أول حيوان.'))
        : ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, i) {
              final a = animals[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.pets)),
                  title: Text((a['name'] ?? '').toString()),
                  subtitle: Text('رقم: ' + (a['identifier'] ?? '').toString() +
                      ' • ' + (a['life_stage'] ?? '').toString() +
                      ' • ' + number(a['weight_kg'] as double?) + ' كغ\n' +
                      'آخر قياس: ' + ((a['measured_at'] ?? '').toString().split('T').first)),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'حذف الحيوان وسجلاته',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => remove(a),
                  ),
                ),
              );
            },
          )),
  ]);
}
