import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../sales/domain/entities/cart_line.dart';
import '../../../sales/domain/services/cart_rules.dart';
import '../../../sales/sales_providers.dart';

class CustomerCartState extends Equatable {
  const CustomerCartState({this.lines = const [], this.note = '', this.submission = const AsyncData(null)});

  final List<CartLine> lines;
  final String note;
  final AsyncValue<void> submission;

  int get subtotal => lines.fold(0, (sum, l) => sum + l.gross);

  int get itemCount => lines.fold(0, (sum, l) => sum + l.qty);

  CustomerCartState copyWith({List<CartLine>? lines, String? note, AsyncValue<void>? submission}) => CustomerCartState(
        lines: lines ?? this.lines,
        note: note ?? this.note,
        submission: submission ?? this.submission,
      );

  @override
  List<Object?> get props => [lines, note, submission];
}

/// Keranjang Customer. Harga yang terlihat selalu harga normal (atau grosir otomatis).
class CustomerCartViewModel extends Notifier<CustomerCartState> {
  @override
  CustomerCartState build() => const CustomerCartState();

  /// Qty dipotong ke stok tersedia. Mengembalikan pesan bila qty disesuaikan.
  String? add(Product product, int qty) {
    final (lines, added) = CartRules.addClamped(state.lines, product, qty);
    state = state.copyWith(lines: lines);
    if (added == 0) return 'Stok ${product.name} habis atau sudah semua di keranjang.';
    if (added < qty) return 'Stok tersedia hanya ${product.stock}. Qty disesuaikan.';
    return null;
  }

  String? setQty(int index, int qty, Product product) {
    final others = CartRules.qtyInCart(state.lines, product.id, exceptIndex: index);
    final max = product.trackStock ? product.stock - others : qty;
    final clamped = qty.clamp(0, max < 0 ? 0 : max);
    state = state.copyWith(lines: CartRules.setQty(state.lines, index, clamped, product));
    return clamped < qty ? 'Stok tersedia hanya ${product.stock}.' : null;
  }

  void setNote(String note) => state = state.copyWith(note: note);

  Future<bool> checkout() async {
    state = state.copyWith(submission: const AsyncLoading());
    final result = await AsyncValue.guard(() => ref.read(salesRepositoryProvider).placeOrder(
          customer: ref.read(currentUserProvider),
          lines: state.lines,
          note: state.note.trim(),
        ));
    if (!ref.mounted) return false;
    if (result.hasError) {
      state = state.copyWith(submission: AsyncError(result.error!, result.stackTrace!));
      return false;
    }
    state = const CustomerCartState();
    return true;
  }
}

final customerCartViewModelProvider =
    NotifierProvider<CustomerCartViewModel, CustomerCartState>(CustomerCartViewModel.new);
