import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../pricing/pricing_providers.dart';
import '../../../settings/settings_providers.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/services/cart_rules.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';

/// Aksi Owner atas pesanan online dan nota.
class OrderActionsViewModel extends ActionViewModel {
  /// Pratinjau baris pesanan setelah harga khusus / promo customer diterapkan.
  List<CartLine> previewLines(SalesOrder order) => CartRules.applyDiscounts(
        order.lines,
        customerId: order.customerId,
        discounts: ref.read(discountsProvider).value ?? const [],
        now: ref.read(clockProvider)(),
      );

  Future<String?> process(SalesOrder order, {OrderDiscount orderDiscount = const OrderDiscount.none()}) async {
    String? invoiceId;
    final ok = await run(() async {
      // Pastikan diskon & pajak sudah termuat, bukan nilai kosong saat loading.
      await readReady(discountsProvider.future);
      final settings = await readReady(storeSettingsProvider.future);
      invoiceId = await ref.read(salesRepositoryProvider).processOrder(
            order: order,
            pricedLines: previewLines(order),
            orderDiscount: orderDiscount,
            taxPercent: settings.effectiveTax,
            by: ref.read(currentUserProvider),
          );
    });
    return ok ? invoiceId : null;
  }

  Future<bool> assignCourier(SalesOrder order, AppUser courier) => run(() => ref
      .read(salesRepositoryProvider)
      .assignCourier(order: order, courier: courier, by: ref.read(currentUserProvider)));

  Future<bool> moveStatus(SalesOrder order, OrderStatus to) => run(() => ref
      .read(salesRepositoryProvider)
      .moveStatus(order: order, to: to, by: ref.read(currentUserProvider)));

  /// Dipakai Owner dan Customer (Customer hanya saat status Menunggu).
  Future<bool> cancel(SalesOrder order, String reason) => run(() => ref
      .read(salesRepositoryProvider)
      .cancelOrder(order: order, reason: reason, by: ref.read(currentUserProvider)));

  Future<bool> addPayment(Invoice invoice, int amount, PaymentMethod method) => run(() => ref
      .read(salesRepositoryProvider)
      .addPayment(invoice: invoice, amount: amount, method: method, by: ref.read(currentUserProvider)));

  Future<bool> setCreditTerm(Invoice invoice, DateTime dueDate) => run(() => ref
      .read(salesRepositoryProvider)
      .setCreditTerm(invoice: invoice, dueDate: dueDate, by: ref.read(currentUserProvider)));
}

final orderActionsViewModelProvider =
    NotifierProvider<OrderActionsViewModel, AsyncValue<void>>(OrderActionsViewModel.new);
