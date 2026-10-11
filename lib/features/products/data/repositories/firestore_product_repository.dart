import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/collections.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../models/product_model.dart';
import '../../../../core/firebase/tenant_store.dart';

class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository(this._store);

  final TenantStore _store;

  FirebaseFirestore get _db => _store.db;

  CollectionReference<Map<String, dynamic>> get _products => _store.col(Collections.products);
  CollectionReference<Map<String, dynamic>> get _costs => _store.col(Collections.productCosts);

  @override
  Stream<List<Product>> watchProducts({bool activeOnly = false}) {
    Query<Map<String, dynamic>> query = _products;
    if (activeOnly) query = query.where('active', isEqualTo: true);
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  @override
  Stream<Product?> watchProduct(String id) => _products
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? ProductModel.fromMap(s.id, s.data()!) : null);

  @override
  Future<ProductCost?> getCost(String productId) async {
    final snap = await _costs.doc(productId).get();
    return snap.exists ? ProductModel.costFromMap(productId, snap.data()) : null;
  }

  @override
  Stream<Map<String, ProductCost>> watchCosts() => _costs.snapshots().map((snap) => {
        for (final d in snap.docs) d.id: ProductModel.costFromMap(d.id, d.data()),
      });

  @override
  Future<String> saveProduct(Product product, {required int buyPrice, required String userId}) async {
    final isNew = product.id.isEmpty;
    final ref = isNew ? _products.doc() : _products.doc(product.id);
    final batch = _db.batch();

    if (isNew) {
      batch.set(ref, {
        ...ProductModel.toEditableMap(product),
        'stock': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_costs.doc(ref.id), {'buyPrice': buyPrice, 'hpp': buyPrice});
    } else {
      final before = await ref.get();
      final oldPrice = before.data()?['sellPrice'];
      batch.update(ref, {...ProductModel.toEditableMap(product), 'updatedAt': FieldValue.serverTimestamp()});
      batch.set(_costs.doc(ref.id), {'buyPrice': buyPrice}, SetOptions(merge: true));
      if (oldPrice != product.sellPrice) {
        batch.set(_store.col(Collections.priceHistory).doc(), {
          'productId': ref.id,
          'oldPrice': oldPrice,
          'newPrice': product.sellPrice,
          'changedBy': userId,
          'changedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
    return ref.id;
  }

  @override
  Future<int> createProductsIfMissing(List<({Product product, int buyPrice})> items) async {
    final ids = (await _products.get()).docs.map((d) => d.id).toSet();
    final batch = _db.batch();
    var created = 0;
    for (final item in items.where((i) => !ids.contains(i.product.id))) {
      batch.set(_products.doc(item.product.id), {
        ...ProductModel.toEditableMap(item.product),
        'stock': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(_costs.doc(item.product.id), {'buyPrice': item.buyPrice, 'hpp': item.buyPrice});
      created++;
    }
    if (created > 0) await batch.commit();
    return created;
  }

  @override
  Future<void> setActive(String id, bool active) =>
      _products.doc(id).update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});
}
