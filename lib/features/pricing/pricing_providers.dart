import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/firestore_discount_repository.dart';
import 'domain/entities/discount.dart';
import 'domain/repositories/discount_repository.dart';

final discountRepositoryProvider = Provider<DiscountRepository>(
  (ref) => FirestoreDiscountRepository(ref.watch(firestoreProvider)),
);

/// Hanya untuk Owner.
final discountsProvider = StreamProvider<List<Discount>>(
  (ref) => ref.watch(discountRepositoryProvider).watchAll(),
);

final catalogPromosProvider = StreamProvider<List<Discount>>(
  (ref) => ref.watch(discountRepositoryProvider).watchCatalogPromos(),
);
