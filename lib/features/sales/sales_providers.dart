import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/domain/entities/app_user.dart';
import '../auth/domain/entities/user_role.dart';
import 'data/repositories/firestore_sales_repository.dart';
import 'domain/entities/invoice.dart';
import 'domain/entities/sales_order.dart';
import 'domain/repositories/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => FirestoreSalesRepository(ref.watch(tenantStoreProvider), ref.watch(clockProvider)),
);

/// Owner: semua pesanan. Customer: pesanannya. SPV: pesanan yang ia antar sebagai kurir.
final ordersProvider = StreamProvider<List<SalesOrder>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.watch(salesRepositoryProvider);
  return switch (user.role) {
    UserRole.owner => repo.watchOrders(),
    UserRole.spv => repo.watchOrders(courierId: user.uid),
    UserRole.customer => repo.watchOrders(customerId: user.uid),
  };
});

/// SPV yang bisa ditugaskan sebagai kurir.
final couriersProvider = StreamProvider<List<AppUser>>((ref) => ref
    .watch(userRepositoryProvider)
    .watchUsers(distributorId: ref.watch(currentUserProvider).distributorId, role: UserRole.spv));

final orderProvider = StreamProvider.family<SalesOrder?, String>(
  (ref, id) => ref.watch(salesRepositoryProvider).watchOrder(id),
);

final pendingOrderCountProvider = Provider<int>(
  (ref) => ref.watch(ordersProvider).value?.where((o) => o.status == OrderStatus.pending).length ?? 0,
);

final invoiceProvider = StreamProvider.family<Invoice?, String>(
  (ref, id) => ref.watch(salesRepositoryProvider).watchInvoice(id),
);

final paymentsProvider = StreamProvider.family<List<PaymentRecord>, String>((ref, invoiceId) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(salesRepositoryProvider).watchPayments(invoiceId, customerId: user.isOwner ? null : user.uid);
});

/// Customer: semua nota miliknya.
final myInvoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(salesRepositoryProvider).watchInvoices(customerId: user.uid);
});
