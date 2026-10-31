import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/feedback.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/product_view_models.dart';

Future<bool> deleteProduct(BuildContext context, WidgetRef ref, Product product) async {
  final accepted = await confirm(
    context,
    title: 'Hapus produk?',
    message: 'Hapus "${product.name}" dari daftar produk dan katalog? Riwayat transaksi tetap tersimpan.',
  );
  if (!accepted || !context.mounted) return false;
  final ok = await ref.read(productFormViewModelProvider.notifier).deleteProduct(product);
  if (context.mounted) {
    showMessage(context, ok ? 'Produk dihapus' : '${ref.read(productFormViewModelProvider).error}', isError: !ok);
  }
  return ok;
}
