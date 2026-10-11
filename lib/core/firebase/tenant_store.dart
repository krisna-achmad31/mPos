import 'package:cloud_firestore/cloud_firestore.dart';

import 'collections.dart';

/// Akses Firestore yang selalu terkunci ke satu distributor:
/// `distributors/{distributorId}/<koleksi>`. Semua data bisnis lewat sini,
/// sehingga data antar distributor tidak pernah tercampur.
class TenantStore {
  TenantStore(this.db, this.distributorId) {
    if (distributorId.isEmpty) throw StateError('Akun belum terhubung ke distributor');
  }

  final FirebaseFirestore db;
  final String distributorId;

  DocumentReference<Map<String, dynamic>> get root => db.collection(Collections.distributors).doc(distributorId);

  CollectionReference<Map<String, dynamic>> col(String name) => root.collection(name);
}
