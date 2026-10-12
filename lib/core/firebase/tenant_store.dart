import 'package:cloud_firestore/cloud_firestore.dart';

import 'collections.dart';

/// Akses Firestore yang selalu terkunci ke satu tenant: distributor (`distributors/{id}/<koleksi>`)
/// atau POS kopi milik pelanggan (`cafes/{id}/<koleksi>`). Semua data bisnis lewat sini,
/// sehingga data antar tenant tidak pernah tercampur.
class TenantStore {
  TenantStore(this.db, String distributorId)
      : root = _root(db, Collections.distributors, distributorId, 'Akun belum terhubung ke distributor');

  /// POS kopi: koleksi yang sama (produk = menu, nota = struk, pengeluaran, laporan) di bawah `cafes/{cafeId}`.
  TenantStore.cafe(this.db, String cafeId) : root = _root(db, Collections.cafes, cafeId, 'Akun belum terhubung ke POS kopi');

  final FirebaseFirestore db;
  final DocumentReference<Map<String, dynamic>> root;

  bool get isCafe => root.parent.id == Collections.cafes;

  CollectionReference<Map<String, dynamic>> col(String name) => root.collection(name);

  static DocumentReference<Map<String, dynamic>> _root(FirebaseFirestore db, String collection, String id, String error) {
    if (id.isEmpty) throw StateError(error);
    return db.collection(collection).doc(id);
  }
}
