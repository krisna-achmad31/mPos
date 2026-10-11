import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositories/firestore_product_repository.dart';
import 'domain/entities/product.dart';
import 'domain/repositories/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => FirestoreProductRepository(ref.watch(firestoreProvider)),
);

final productsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).watchProducts(),
);

final activeProductsProvider = StreamProvider<List<Product>>(
  (ref) => ref.watch(productRepositoryProvider).watchProducts(activeOnly: true),
);

final productProvider = StreamProvider.family<Product?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).watchProduct(id),
);

final productCostProvider = FutureProvider.family<ProductCost?, String>(
  (ref, id) => ref.watch(productRepositoryProvider).getCost(id),
);

/// Hanya Owner yang boleh membaca ini (dijaga Firestore rules).
final productCostsProvider = StreamProvider<Map<String, ProductCost>>(
  (ref) => ref.watch(productRepositoryProvider).watchCosts(),
);
