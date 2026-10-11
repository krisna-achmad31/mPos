import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'data/firestore_discount_repository.dart';
import 'domain/entities/discount.dart';
import 'domain/repositories/discount_repository.dart';

final discountRepositoryProvider = Provider<DiscountRepository>(
  (ref) => FirestoreDiscountRepository(ref.watch(tenantStoreProvider)),
);

/// Hanya untuk Owner.
final discountsProvider = StreamProvider<List<Discount>>(
  (ref) => ref.watch(discountRepositoryProvider).watchAll(),
);

/// Promo yang terlihat oleh pelanggan yang login.
final catalogPromosProvider = StreamProvider<List<Discount>>(
  (ref) => ref.watch(discountRepositoryProvider).watchCatalogPromos(ref.watch(currentUserProvider).uid),
);
