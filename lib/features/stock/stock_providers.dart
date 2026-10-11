import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/repositories/firestore_stock_repository.dart';
import 'domain/entities/change_request.dart';
import 'domain/entities/stock_receipt.dart';
import 'domain/repositories/stock_repository.dart';

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => FirestoreStockRepository(ref.watch(tenantStoreProvider)),
);

/// Owner melihat semua dokumen; SPV hanya miliknya.
final stockReceiptsProvider = StreamProvider<List<StockReceipt>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(stockRepositoryProvider).watchReceipts(createdBy: user.isOwner ? null : user.uid);
});

final changeRequestsProvider = StreamProvider<List<ChangeRequest>>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(stockRepositoryProvider).watchChangeRequests(requestedBy: user.isOwner ? null : user.uid);
});

final pendingChangeCountProvider = Provider<int>((ref) =>
    ref.watch(changeRequestsProvider).value?.where((r) => r.status == ChangeRequestStatus.pending).length ?? 0);
