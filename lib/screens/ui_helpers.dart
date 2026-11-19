import 'package:flutter/material.dart';

double? parseNumber(String text) {
  var s = text.trim().replaceAll('٫', '.').replaceAll('٬', '');
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
  }
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

String number(double? value, {int decimals = 2}) =>
    value == null ? 'غير متوفر' : value.toStringAsFixed(decimals);

Widget numberField(
  TextEditingController controller,
  String label, {
  String? hint,
}) =>
    TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

Widget stringField(TextEditingController controller, String label,
        {int maxLines = 1}) =>
    TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );

bool validOptionalNumber(String s, {double min = 0, double? max}) {
  if (s.trim().isEmpty) return true;
  final n = parseNumber(s);
  return n != null && n.isFinite && n >= min && (max == null || n <= max);
}

void message(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Widget notice(String text, {IconData icon = Icons.info_outline}) =>
    Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
