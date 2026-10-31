import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../../settings/settings_providers.dart';
import '../../data/product_pdf.dart';
import '../../data/product_xlsx.dart';
import '../../domain/product_export.dart';
import '../../product_providers.dart';
import 'product_view_models.dart';

enum ProductExportFormat { excel, pdf }

class ProductExportViewModel extends ActionViewModel {
  Future<ProductExportData> snapshot() async {
    final products = ref.read(filteredProductsProvider).requireValue;
    if (products.isEmpty) throw const AppException('Tidak ada produk untuk diekspor.');
    final filter = ref.read(productFilterProvider);
    final query = ref.read(productSearchProvider).trim();
    final scope = [
      if (query.isNotEmpty) 'Pencarian: $query',
      if (filter.stock != StockFilter.all) 'Stok: ${filter.stock.label}',
      if (filter.type != ProductTypeFilter.all) filter.type.label,
      if (filter.status != ActiveFilter.all) filter.status.label,
      if (filter.category != null) 'Kategori: ${filter.category}',
    ];
    final settings = await readReady(storeSettingsProvider.future);
    final logo = await readReady(distributorLogoProvider.future);
    final distributor = await readReady(currentDistributorProvider.future);
    final costs = await readReady(productCostsProvider.future);
    return ProductExportData(
      products: List.unmodifiable(products),
      costs: Map.unmodifiable(costs),
      settings: settings,
      distributorName: distributor?.name ?? '',
      logoPng: logo,
      exportedAt: ref.read(clockProvider)(),
      scope: scope.isEmpty ? 'Semua produk' : scope.join(' | '),
    );
  }

  Future<bool> export(ProductExportFormat format) => run(() async {
    final data = await snapshot();
    final excel = format == ProductExportFormat.excel;
    final extension = excel ? 'xlsx' : 'pdf';
    final bytes = excel ? ProductXlsx.build(data) : await buildProductPdf(data);
    await FilePicker.saveFile(
      fileName: data.fileName(extension),
      bytes: bytes,
      mimeType: excel ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' : 'application/pdf',
      type: FileType.custom,
      allowedExtensions: [extension],
    );
  });
}

final productExportViewModelProvider = NotifierProvider<ProductExportViewModel, AsyncValue<void>>(
  ProductExportViewModel.new,
);
