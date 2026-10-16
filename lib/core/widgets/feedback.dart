import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

void showMessage(BuildContext context, String message, {bool isError = false}) {
  final tokens = context.tokens;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? tokens.danger : null,
    ));
}

/// Dialog yang meminta teks wajib (alasan batal, catatan tolak, dll.).
Future<String?> askReason(BuildContext context, {required String title, String label = 'Alasan'}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, {required String title, required String message}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya')),
      ],
    ),
  );
  return result ?? false;
}
