import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../domain/entities/discount.dart';
import '../domain/repositories/discount_repository.dart';
import '../../../core/firebase/tenant_store.dart';

class FirestoreDiscountRepository implements DiscountRepository {
  FirestoreDiscountRepository(this._store);

  final TenantStore _store;

  CollectionReference<Map<String, dynamic>> get _col => _store.col(Collections.discounts);

  Discount _fromMap(String id, Map<String, dynamic> m) => Discount(
        id: id,
        name: readString(m['name']),
        kind: m['kind'] == DiscountKind.special.name ? DiscountKind.special : DiscountKind.promo,
        type: m['type'] == DiscountType.amount.name ? DiscountType.amount : DiscountType.percent,
        value: readDouble(m['value']),
        productId: readNullableString(m['productId']),
        productName: readString(m['productName']),
        customerId: readNullableString(m['customerId']),
        customerName: readString(m['customerName']),
        visibleInCatalog: readBool(m['visibleInCatalog']),
        start: readNullableDate(m['start']),
        end: readNullableDate(m['end']),
        active: readBool(m['active'], fallback: true),
      );

  Map<String, dynamic> _toMap(Discount d) => {
        'name': d.name,
        'kind': d.kind.name,
        'type': d.type.name,
        'value': d.value,
        'productId': d.productId,
        'productName': d.productName,
        'customerId': d.customerId,
        'customerName': d.customerName,
        // Harga khusus tidak pernah tampil di katalog. Promo boleh, untuk publik atau satu akun.
        'visibleInCatalog': d.kind == DiscountKind.promo && d.visibleInCatalog,
        // Siapa yang boleh membaca promo ini dari katalog: 'all' atau uid pelanggan.
        'audience': d.customerId ?? 'all',
        'start': d.start == null ? null : Timestamp.fromDate(d.start!),
        'end': d.end == null ? null : Timestamp.fromDate(d.end!),
        'active': d.active,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  @override
  Stream<List<Discount>> watchAll() => _col.snapshots().map((snap) {
        final list = snap.docs.map((d) => _fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  @override
  Stream<List<Discount>> watchCatalogPromos(String customerId) => _col
      .where('visibleInCatalog', isEqualTo: true)
      .where('audience', whereIn: ['all', customerId])
      .snapshots()
      .map((snap) => snap.docs.map((d) => _fromMap(d.id, d.data())).toList());

  @override
  Future<void> save(Discount d) =>
      d.id.isEmpty ? _col.add(_toMap(d)) : _col.doc(d.id).set(_toMap(d), SetOptions(merge: true));

  @override
  Future<void> setActive(String id, bool active) => _col.doc(id).update({'active': active});
}
