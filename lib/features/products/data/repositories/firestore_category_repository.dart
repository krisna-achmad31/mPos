import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/collections.dart';
import '../../../../core/firebase/tenant_store.dart';
import '../../domain/entities/product_categories.dart';

/// Daftar kategori per distributor: `settings/categories.items` (tambahan Owner).
class FirestoreCategoryRepository {
  FirestoreCategoryRepository(this._store);

  final TenantStore _store;

  DocumentReference<Map<String, dynamic>> get _doc => _store.col(Collections.settings).doc('categories');

  Stream<List<String>> watch() => _doc.snapshots().map((s) {
        final items = s.data()?['items'];
        return ProductCategories.merge(items is List ? items.whereType<String>() : const []);
      });

  Future<String> add(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('Nama kategori wajib diisi.');
    await _doc.set({
      'items': FieldValue.arrayUnion([clean]),
    }, SetOptions(merge: true));
    return clean;
  }
}
