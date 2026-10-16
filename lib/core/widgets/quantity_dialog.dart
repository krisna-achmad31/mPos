import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Ketik qty langsung (mis. 25) — sistem yang memecah ke karton / bal / sak.
Future<int?> askQuantity(BuildContext context, {required int current, required String unit, String? hint}) {
  final controller = TextEditingController(text: '$current');
  final theme = Theme.of(context);
  final tokens = context.tokens;
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ubah jumlah'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Jumlah ($unit)',
                  helperText: hint ?? '0 = hapus dari keranjang',
                ),
                onSubmitted: (v) => Navigator.pop(context, int.tryParse(v) ?? 0),
              ),
              Text(
                'Sistem memecah jumlah ini ke karton / bal / sak secara otomatis.',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? 0), child: const Text('OK')),
      ],
    ),
  );
}
