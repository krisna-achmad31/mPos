import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ketik qty langsung (mis. 25) — sistem yang memecah ke karton / bal / sak.
Future<int?> askQuantity(BuildContext context, {required int current, required String unit, String? hint}) {
  final controller = TextEditingController(text: '$current');
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ubah jumlah'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: 'Jumlah ($unit)', helperText: hint ?? '0 = hapus dari keranjang'),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v) ?? 0),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? 0), child: const Text('OK')),
      ],
    ),
  );
}
