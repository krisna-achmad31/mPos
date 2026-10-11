import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/audit.dart';
import '../../../../core/firebase/collections.dart';
import '../../../../core/firebase/firestore_parsing.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/change_request.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/services/stock_calculator.dart';
import '../models/stock_models.dart';
import '../../../../core/firebase/tenant_store.dart';

class FirestoreStockRepository implements StockRepository {
  FirestoreStockRepository(this._store);

  final TenantStore _store;

  FirebaseFirestore get _db => _store.db;

  CollectionReference<Map<String, dynamic>> get _receipts => _store.col(Collections.stockReceipts);
  CollectionReference<Map<String, dynamic>> get _products => _store.col(Collections.products);
  CollectionReference<Map<String, dynamic>> get _costs => _store.col(Collections.productCosts);
  CollectionReference<Map<String, dynamic>> get _requests => _store.col(Collections.changeRequests);

  @override
  Stream<List<StockReceipt>> watchReceipts({String? createdBy}) {
    Query<Map<String, dynamic>> query = _receipts;
    if (createdBy != null) query = query.where('createdBy', isEqualTo: createdBy);
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => StockModels.receiptFromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Future<void> createReceipt(StockReceipt draft, AppUser by) async {
    StockCalculator.validateItems(draft.items);
    if (draft.supplier.trim().isEmpty) throw const AppException('Supplier wajib diisi.');

    await _db.runTransaction((tx) async {
      final ids = draft.items.map((i) => i.productId).toSet();
      final stock = <String, int>{};
      final hpp = <String, int>{};
      for (final id in ids) {
        final product = await tx.get(_products.doc(id));
        if (!product.exists) throw const AppException('Produk tidak ditemukan.');
        final cost = await tx.get(_costs.doc(id));
        stock[id] = readInt(product.data()!['stock']);
        hpp[id] = readInt(cost.data()?['hpp']);
      }

      final receiptRef = _receipts.doc();
      final lastBuyPrice = <String, int>{};
      for (final item in draft.items) {
        hpp[item.productId] = StockCalculator.averageCost(
          currentStock: stock[item.productId]!,
          currentHpp: hpp[item.productId]!,
          incomingQty: item.qty,
          incomingPrice: item.buyPrice,
        );
        stock[item.productId] = stock[item.productId]! + item.qty;
        lastBuyPrice[item.productId] = item.buyPrice;
        writeStockMovement(_store, tx,
            productId: item.productId,
            type: 'in',
            qty: item.qty,
            refType: Collections.stockReceipts,
            refId: receiptRef.id,
            userId: by.uid);
      }

      for (final id in ids) {
        tx.update(_products.doc(id), {'stock': stock[id], 'updatedAt': FieldValue.serverTimestamp()});
        tx.set(_costs.doc(id), {'buyPrice': lastBuyPrice[id], 'hpp': hpp[id]}, SetOptions(merge: true));
      }
      tx.set(receiptRef, {
        ...StockModels.receiptToMap(draft),
        'createdBy': by.uid,
        'createdByName': by.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      writeAudit(_store, tx,
          userId: by.uid,
          userName: by.name,
          action: 'create',
          entity: Collections.stockReceipts,
          entityId: receiptRef.id,
          after: StockModels.itemsToMap(draft.items));
    });
  }

  @override
  Future<void> requestChange({
    required StockReceipt receipt,
    required List<StockReceiptItem> newItems,
    required String reason,
    required AppUser by,
  }) async {
    StockCalculator.validateItems(newItems);
    if (reason.trim().isEmpty) throw const AppException('Alasan wajib diisi.');
    if (StockCalculator.deltas(receipt.items, newItems).isEmpty) {
      throw const AppException('Tidak ada perubahan qty.');
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_receipts.doc(receipt.id));
      if (snap.data()?['status'] == 'pending_change') {
        throw const AppException('Dokumen ini masih punya pengajuan yang menunggu ACC Owner.');
      }
      tx.set(_requests.doc(), {
        'receiptId': receipt.id,
        'receiptDocNo': receipt.docNo,
        'oldItems': StockModels.itemsToMap(receipt.items),
        'newItems': StockModels.itemsToMap(newItems),
        'reason': reason.trim(),
        'requestedBy': by.uid,
        'requestedByName': by.name,
        'status': ChangeRequestStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(_receipts.doc(receipt.id), {'status': 'pending_change'});
    });
  }

  @override
  Future<void> applyChange({
    required StockReceipt receipt,
    required List<StockReceiptItem> newItems,
    required AppUser by,
  }) async {
    StockCalculator.validateItems(newItems);
    await _db.runTransaction((tx) async {
      final current = await tx.get(_receipts.doc(receipt.id));
      final oldItems = readMapList(current.data()?['items']).map(StockModels.itemFromMap).toList();
      final apply = await _prepareChange(tx, receipt.id, oldItems, newItems, by);
      apply();
    });
  }

  @override
  Stream<List<ChangeRequest>> watchChangeRequests({String? requestedBy}) {
    Query<Map<String, dynamic>> query = _requests;
    if (requestedBy != null) query = query.where('requestedBy', isEqualTo: requestedBy);
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => StockModels.requestFromMap(d.id, d.data())).toList();
      list.sort((a, b) {
        final pendingFirst = (a.status == ChangeRequestStatus.pending ? 0 : 1)
            .compareTo(b.status == ChangeRequestStatus.pending ? 0 : 1);
        return pendingFirst != 0 ? pendingFirst : b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  @override
  Future<void> decideChange({
    required ChangeRequest request,
    required bool approve,
    required String note,
    required AppUser by,
  }) async {
    if (!approve && note.trim().isEmpty) throw const AppException('Catatan penolakan wajib diisi.');

    await _db.runTransaction((tx) async {
      final requestRef = _requests.doc(request.id);
      final requestSnap = await tx.get(requestRef);
      if (requestSnap.data()?['status'] != ChangeRequestStatus.pending.name) {
        throw const AppException('Pengajuan ini sudah diputuskan.');
      }

      void Function()? apply;
      if (approve) {
        final receipt = await tx.get(_receipts.doc(request.receiptId));
        final oldItems = readMapList(receipt.data()?['items']).map(StockModels.itemFromMap).toList();
        apply = await _prepareChange(tx, request.receiptId, oldItems, request.newItems, by);
      }

      // Semua baca selesai; mulai menulis.
      if (apply != null) {
        apply();
      } else {
        tx.update(_receipts.doc(request.receiptId), {'status': 'active'});
      }
      tx.update(requestRef, {
        'status': approve ? ChangeRequestStatus.approved.name : ChangeRequestStatus.rejected.name,
        'decidedBy': by.uid,
        'decidedByName': by.name,
        'decisionNote': note.trim(),
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Membaca stok produk yang terdampak, memvalidasi, lalu mengembalikan fungsi tulis.
  /// Dipisah agar semua `tx.get` terjadi sebelum `tx.update` (aturan transaksi Firestore).
  Future<void Function()> _prepareChange(
    Transaction tx,
    String receiptId,
    List<StockReceiptItem> oldItems,
    List<StockReceiptItem> newItems,
    AppUser by,
  ) async {
    final deltas = StockCalculator.deltas(oldItems, newItems);
    final stock = <String, int>{};
    for (final entry in deltas.entries) {
      final snap = await tx.get(_products.doc(entry.key));
      final current = readInt(snap.data()?['stock']);
      final next = current + entry.value;
      if (next < 0) {
        final name = readString(snap.data()?['name']);
        throw AppException('Stok $name akan minus ($next). Barang sudah terjual sebagian.');
      }
      stock[entry.key] = next;
    }

    return () {
      for (final entry in deltas.entries) {
        tx.update(_products.doc(entry.key), {'stock': stock[entry.key], 'updatedAt': FieldValue.serverTimestamp()});
        writeStockMovement(_store, tx,
            productId: entry.key,
            type: 'adjust',
            qty: entry.value,
            refType: Collections.stockReceipts,
            refId: receiptId,
            userId: by.uid);
      }
      final total = newItems.fold<int>(0, (acc, i) => acc + i.total);
      tx.update(_receipts.doc(receiptId), {
        'items': StockModels.itemsToMap(newItems),
        'productIds': newItems.map((i) => i.productId).toSet().toList(),
        'total': total,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writeAudit(_store, tx,
          userId: by.uid,
          userName: by.name,
          action: 'update',
          entity: Collections.stockReceipts,
          entityId: receiptId,
          before: StockModels.itemsToMap(oldItems),
          after: StockModels.itemsToMap(newItems));
    };
  }

  @override
  Future<void> adjustStock({
    required String productId,
    required int physicalQty,
    required String note,
    required AppUser by,
  }) async {
    if (physicalQty < 0) throw const AppException('Stok fisik tidak boleh negatif.');
    await _db.runTransaction((tx) async {
      final ref = _products.doc(productId);
      final snap = await tx.get(ref);
      final systemQty = readInt(snap.data()?['stock']);
      final diff = physicalQty - systemQty;
      final opnameRef = _store.col(Collections.stockOpnames).doc();

      tx.set(opnameRef, {
        'productId': productId,
        'productName': readString(snap.data()?['name']),
        'systemQty': systemQty,
        'physicalQty': physicalQty,
        'diff': diff,
        'note': note,
        'userId': by.uid,
        'at': FieldValue.serverTimestamp(),
      });
      if (diff != 0) {
        tx.update(ref, {'stock': physicalQty, 'updatedAt': FieldValue.serverTimestamp()});
        writeStockMovement(_store, tx,
            productId: productId,
            type: 'opname',
            qty: diff,
            refType: Collections.stockOpnames,
            refId: opnameRef.id,
            userId: by.uid);
      }
      writeAudit(_store, tx,
          userId: by.uid,
          userName: by.name,
          action: 'opname',
          entity: Collections.products,
          entityId: productId,
          before: systemQty,
          after: physicalQty);
    });
  }
}
