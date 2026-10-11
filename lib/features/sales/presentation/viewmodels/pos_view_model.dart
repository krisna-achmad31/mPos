import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../pricing/pricing_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../settings/settings_providers.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/services/cart_rules.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';

class PosState extends Equatable {
  const PosState({
    this.lines = const [],
    this.customer,
    this.salesName = '',
    this.orderDiscount = const OrderDiscount.none(),
    this.method = PaymentMethod.cash,
    this.amountGiven = 0,
    this.submission = const AsyncData(null),
    this.message,
  });

  final List<CartLine> lines;

  /// null = pelanggan umum.
  final AppUser? customer;
  final String salesName;
  final OrderDiscount orderDiscount;
  final PaymentMethod method;
  final int amountGiven;
  final AsyncValue<String?> submission;

  /// Pesan validasi terakhir (mis. stok kurang).
  final String? message;

  String get customerName => customer?.displayName ?? 'UMUM';

  PosState copyWith({
    List<CartLine>? lines,
    AppUser? Function()? customer,
    String? salesName,
    OrderDiscount? orderDiscount,
    PaymentMethod? method,
    int? amountGiven,
    AsyncValue<String?>? submission,
    String? Function()? message,
  }) =>
      PosState(
        lines: lines ?? this.lines,
        customer: customer != null ? customer() : this.customer,
        salesName: salesName ?? this.salesName,
        orderDiscount: orderDiscount ?? this.orderDiscount,
        method: method ?? this.method,
        amountGiven: amountGiven ?? this.amountGiven,
        submission: submission ?? this.submission,
        message: message != null ? message() : this.message,
      );

  @override
  List<Object?> get props => [lines, customer, salesName, orderDiscount, method, amountGiven, submission, message];
}

/// Layar kasir langsung (Owner).
class PosViewModel extends Notifier<PosState> {
  @override
  PosState build() => const PosState();

  void addProduct(Product product, {int qty = 1, int? manualPrice}) {
    try {
      state = state.copyWith(
        lines: CartRules.addItem(state.lines, product, qty: qty, manualPrice: manualPrice),
        message: () => null,
      );
    } catch (e) {
      state = state.copyWith(message: () => '$e');
    }
  }

  void setQty(int index, int qty, Product product) {
    try {
      state = state.copyWith(lines: CartRules.setQty(state.lines, index, qty, product), message: () => null);
    } catch (e) {
      state = state.copyWith(message: () => '$e');
    }
  }

  void removeLine(int index) => state = state.copyWith(lines: [...state.lines]..removeAt(index));

  void setCustomer(AppUser? customer) => state = state.copyWith(customer: () => customer);

  void setSalesName(String name) => state = state.copyWith(salesName: name);

  void setOrderDiscount(OrderDiscount discount) => state = state.copyWith(orderDiscount: discount);

  void setMethod(PaymentMethod method) => state = state.copyWith(method: method);

  void setAmountGiven(int amount) => state = state.copyWith(amountGiven: amount);

  void clearMessage() => state = state.copyWith(message: () => null);

  /// Baris keranjang setelah harga khusus / promo customer diterapkan.
  List<CartLine> pricedLines() => CartRules.applyDiscounts(
        state.lines,
        customerId: state.customer?.uid,
        discounts: ref.read(discountsProvider).value ?? const [],
        now: ref.read(clockProvider)(),
      );

  double get taxPercent => ref.read(storeSettingsProvider).value?.effectiveTax ?? 0;

  /// Menyimpan transaksi. Mengembalikan id nota bila sukses.
  Future<String?> checkout() async {
    state = state.copyWith(submission: const AsyncLoading());
    final result = await AsyncValue.guard(() => ref.read(salesRepositoryProvider).createPosSale(
          pricedLines: pricedLines(),
          customerId: state.customer?.uid,
          customerName: state.customerName,
          salesName: state.salesName.trim(),
          orderDiscount: state.orderDiscount,
          taxPercent: taxPercent,
          method: state.method,
          amountGiven: state.amountGiven,
          by: ref.read(currentUserProvider),
        ));
    if (!ref.mounted) return null;
    if (result.hasError) {
      state = state.copyWith(submission: result);
      return null;
    }
    state = const PosState();
    return result.value;
  }
}

final posViewModelProvider = NotifierProvider<PosViewModel, PosState>(PosViewModel.new);

/// Total yang ditampilkan di layar kasir, selalu sinkron dengan keranjang dan diskon.
final posTotalsProvider = Provider<SaleTotals>((ref) {
  final state = ref.watch(posViewModelProvider);
  ref.watch(discountsProvider);
  ref.watch(storeSettingsProvider);
  final vm = ref.read(posViewModelProvider.notifier);
  return SaleCalculator.totals(vm.pricedLines(), orderDiscount: state.orderDiscount, taxPercent: vm.taxPercent);
});
