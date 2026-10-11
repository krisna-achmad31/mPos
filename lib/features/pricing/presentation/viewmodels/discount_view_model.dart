import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../domain/entities/discount.dart';
import '../../pricing_providers.dart';

class DiscountViewModel extends ActionViewModel {
  Future<bool> save(Discount d) => run(() async {
        if (d.value <= 0) throw const AppException('Nilai diskon harus lebih dari 0.');
        if (d.type == DiscountType.percent && d.value > 100) throw const AppException('Persen maksimal 100.');
        if (d.kind == DiscountKind.special && d.customerId == null) {
          throw const AppException('Harga khusus wajib memilih satu pelanggan dari daftar.');
        }
        if (d.start != null && d.end != null && !d.end!.isAfter(d.start!)) {
          throw const AppException('Tanggal selesai harus setelah tanggal mulai.');
        }
        await ref.read(discountRepositoryProvider).save(d);
      });

  Future<bool> setActive(Discount d, bool active) =>
      run(() => ref.read(discountRepositoryProvider).setActive(d.id, active));
}

final discountViewModelProvider = NotifierProvider<DiscountViewModel, AsyncValue<void>>(DiscountViewModel.new);
