import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/feedback.dart';
import '../viewmodels/product_export_view_model.dart';
import '../viewmodels/product_view_models.dart';

class ProductExportButton extends ConsumerWidget {
  const ProductExportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productExportViewModelProvider);
    final products = ref.watch(filteredProductsProvider);
    ref.listen(productExportViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });
    final enabled = !state.isLoading && products.hasValue && products.requireValue.isNotEmpty;
    return MenuAnchor(
      menuChildren: [
        for (final format in ProductExportFormat.values)
          MenuItemButton(
            onPressed: enabled ? () => ref.read(productExportViewModelProvider.notifier).export(format) : null,
            leadingIcon: Icon(
              format == ProductExportFormat.excel ? Icons.table_view_outlined : Icons.picture_as_pdf_outlined,
            ),
            child: Text(format == ProductExportFormat.excel ? 'Excel (.xlsx)' : 'PDF (.pdf)'),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: 'Ekspor produk sesuai pencarian dan filter saat ini',
        child: OutlinedButton.icon(
          onPressed: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
          icon: state.isLoading
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 18),
          label: Text(state.isLoading ? 'Mengekspor...' : 'Ekspor'),
        ),
      ),
    );
  }
}
