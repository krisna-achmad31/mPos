import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../../core/utils/money.dart';

import '../../settings/domain/store_settings.dart';
import 'entities/product.dart';
import 'services/inventory_summary.dart';

/// Snapshot daftar yang sedang terlihat, digunakan bersama oleh Excel dan PDF.
class ProductExportData {
  const ProductExportData({
    required this.products,
    required this.settings,
    required this.distributorName,
    required this.exportedAt,
    this.logoPng,
    this.scope = 'Semua produk',
    this.costs = const {},
  });

  final List<Product> products;
  final StoreSettings settings;
  final String distributorName;
  final DateTime exportedAt;
  final Uint8List? logoPng;
  final String scope;
  final Map<String, ProductCost> costs;

  int? unitCost(Product product) => costs.containsKey(product.id) ? InventorySummary.unitCost(costs[product.id]) : null;
  int get totalStockValue => InventorySummary.of(products, costs).totalValue;
  bool get hasMissingCosts =>
      products.any((p) => p.trackStock && !p.isBundle && p.stock > 0 && !costs.containsKey(p.id));

  String get name => settings.storeName.trim().isNotEmpty ? settings.storeName.trim() : distributorName;
  String get contact => [
    if (settings.phone.trim().isNotEmpty) 'Telp/WA: ${settings.phone.trim()}',
    if (settings.email.trim().isNotEmpty) settings.email.trim(),
  ].join(' | ');
  String get summary => '${DateFormat('dd/MM/yyyy HH:mm').format(exportedAt)} | ${products.length} produk | $scope';
  String fileName(String extension) => 'Daftar Produk ${DateFormat('yyyyMMdd-HHmm').format(exportedAt)}.$extension';

  static const headers = [
    'No',
    'SKU / Barcode',
    'Nama produk',
    'Kategori',
    'Satuan',
    'Harga satuan (Rp)',
    'Harga grosir (Rp)',
    'Min. grosir',
    'Kemasan / Isi bundle',
    'Stok',
    'Status',
  ];

  List<Object> row(int index) {
    final p = products[index];
    return [
      index + 1,
      [p.sku, p.barcode].where((s) => s.isNotEmpty).join('\n'),
      p.name,
      p.category,
      p.unit,
      p.sellPrice,
      p.hasWholesale ? p.wholesalePrice : '',
      p.hasWholesale ? p.wholesaleMinQty : '',
      p.isBundle
          ? p.bundleItems.map((b) => '${b.qty} ${b.unit} ${b.name}').join('; ')
          : p.packsBySize.map((pack) => '${pack.label(p.unit)}: ${formatRupiah(pack.price)}').join('; '),
      p.trackStock || p.isBundle ? p.stock : '-',
      p.active ? 'Aktif' : 'Nonaktif',
    ];
  }
}
