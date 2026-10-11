import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../auth/auth_providers.dart';
import 'data/repositories/firestore_sales_repository.dart';
import 'domain/entities/invoice.dart';
import 'domain/entities/sales_order.dart';
import 'domain/repositories/sales_repository.dart';

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => FirestoreSalesRepository(ref.watch(firestoreProvider), ref.watch(clockProvider)),
);

/// Owner melihat semua pesanan; Customer hanya miliknya.
final ordersProvider = StreamProvider<List<SalesOrder>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(salesRepositoryProvider).watchOrders(customerId: user.isOwner ? null : user.uid);
});

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
