import 'package:cloud_firestore/cloud_firestore.dart';

import 'collections.dart';

/// Menulis log audit di dalam transaksi yang sama dengan perubahannya.
void writeAudit(
  FirebaseFirestore db,
  Transaction tx, {
  required String userId,
  required String userName,
  required String action,
  required String entity,
  required String entityId,
  Object? before,
  Object? after,
}) {
  tx.set(db.collection(Collections.auditLogs).doc(), {
    'userId': userId,
    'userName': userName,
    'action': action,
    'entity': entity,
    'entityId': entityId,
    'before': before,
    'after': after,
    'at': FieldValue.serverTimestamp(),
  });
}

/// Mutasi stok: setiap perubahan stok punya satu baris di sini.
void writeStockMovement(
  FirebaseFirestore db,
  Transaction tx, {
  required String productId,
  required String type,
  required int qty,
  required String refType,
  required String refId,
  required String userId,
}) {
  tx.set(db.collection(Collections.stockMovements).doc(), {
    'productId': productId,
    'type': type,
    'qty': qty,
    'refType': refType,
    'refId': refId,
    'userId': userId,
    'at': FieldValue.serverTimestamp(),
  });
}
