import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../products/domain/services/inventory_summary.dart';
import '../../../products/product_providers.dart';

class InventoryValueTile extends ConsumerWidget {
  const InventoryValueTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final costs = ref.watch(productCostsProvider);
    String value = 'Memuat...';
    String hint = 'Menunggu data stok dan harga modal';
    if (products.hasError || costs.hasError) {
      value = 'Tidak tersedia';
      hint = 'Data stok atau harga modal gagal dimuat';
    } else if (products.hasValue && costs.hasValue) {
      final missing = products.requireValue.any(
        (p) => p.trackStock && !p.isBundle && p.stock > 0 && !costs.requireValue.containsKey(p.id),
      );
      if (missing) {
        value = 'Belum lengkap';
        hint = 'Lengkapi harga modal produk untuk melihat total';
      } else {
        value = formatRupiah(InventorySummary.of(products.requireValue, costs.requireValue).totalValue);
        hint = 'Modal × stok terkini seluruh produk';
      }
    }
    return KpiTile(label: 'Nilai stok saat ini', value: value, hint: hint, icon: Icons.warehouse_outlined);
  }
}
