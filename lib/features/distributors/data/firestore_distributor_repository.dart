import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../domain/distributor.dart';

class FirestoreDistributorRepository implements DistributorRepository {
  FirestoreDistributorRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Collections.distributors);

  static Distributor fromMap(String id, Map<String, dynamic> m) => Distributor(
        id: id,
        name: readString(m['name']),
        ownerUid: readString(m['ownerUid']),
        phone: readString(m['phone']),
        city: readString(m['city']),
      );

  /// Data untuk membuat distributor baru (dipakai di batch pendaftaran).
  static Map<String, dynamic> newDistributorMap({required String name, required String ownerUid, String phone = ''}) => {
        'name': name.trim(),
        'ownerUid': ownerUid,
        'phone': phone.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Pengaturan toko awal: nama toko = nama distributor.
  static Map<String, dynamic> initialSettingsMap(String name) => {'storeName': name.trim(), 'receiptFooter': 'Terima kasih'};

  @override
  Stream<List<Distributor>> watchAll() => _col.snapshots().map((s) {
        final list = s.docs.map((d) => fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  @override
  Stream<Distributor?> watch(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? fromMap(s.id, s.data()!) : null);

  @override
  Future<void> rename(String id, String name) => _col.doc(id).update({'name': name.trim()});
}
