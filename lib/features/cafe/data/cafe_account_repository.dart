import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/firebase/tenant_store.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../sales/data/models/sales_models.dart';
import '../../sales/domain/entities/cart_line.dart';
import '../../sales/domain/entities/sales_order.dart';
import '../domain/cafe.dart';
import '../domain/cafe_rules.dart';
import 'cafe_repository.dart';

/// Dokumen `cafes/{id}` (status premium) dan kode promo premium milik distributor.
class CafeAccountRepository {
  CafeAccountRepository(this._db, this._now);

  final FirebaseFirestore _db;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _cafes => _db.collection(Collections.cafes);

  Stream<Cafe?> watchCafe(String cafeId) =>
      _cafes.doc(cafeId).snapshots().map((s) => s.exists ? CafeModels.cafeFromMap(s.id, s.data()!) : null);

  /// POS kopi pelanggan distributor ini (untuk Owner distributor memantau premium).
  Stream<List<Cafe>> watchCafesOf(String distributorId) =>
      _cafes.where('distributorId', isEqualTo: distributorId).snapshots().map((snap) {
        final list = [for (final d in snap.docs) CafeModels.cafeFromMap(d.id, d.data())];
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  // ------------------------------------------------------- Kode (distributor)

  Stream<List<PremiumCode>> watchCodes(TenantStore distributor) =>
      distributor.col(Collections.premiumCodes).snapshots().map((snap) {
        final list = [for (final d in snap.docs) CafeModels.codeFromMap(d.id, d.data())];
        list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Future<void> createCode(TenantStore distributor, PremiumCode code, {required AppUser by}) async {
    final id = CafeRules.normalizeCode(code.code);
    if (id.length < 4) throw const AppException('Kode minimal 4 huruf / angka.');
    if (code.days <= 0) throw const AppException('Lama premium harus lebih dari 0 hari.');
    final ref = distributor.col(Collections.premiumCodes).doc(id);
    await _db.runTransaction((tx) async {
      if ((await tx.get(ref)).exists) throw AppException('Kode $id sudah ada.');
      tx.set(ref, {
        'days': code.days,
        'maxUses': code.maxUses < 0 ? 0 : code.maxUses,
        'used': 0,
        'active': true,
        'note': code.note.trim(),
        'createdBy': by.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setCodeActive(TenantStore distributor, String code, bool active) =>
      distributor.col(Collections.premiumCodes).doc(code).update({'active': active});

  // ------------------------------------------------------------ Pelanggan

  /// Pelanggan [customer] memakai kode promo dari distributornya. Satu kode hanya sekali per POS kopi.
  /// Mengembalikan tanggal premium berakhir.
  Future<DateTime> redeem(TenantStore distributor, String rawCode, {required AppUser customer}) async {
    final code = CafeRules.normalizeCode(rawCode);
    if (code.isEmpty) throw const AppException('Masukkan kode promo.');
    final codeRef = distributor.col(Collections.premiumCodes).doc(code);
    final usedRef = codeRef.collection(Collections.redemptions).doc(customer.uid);
    final cafeRef = _cafes.doc(customer.uid);
    late DateTime until;

    await _db.runTransaction((tx) async {
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw const AppException('Kode promo tidak ditemukan.');
      final promo = CafeModels.codeFromMap(code, codeSnap.data()!);
      if (!promo.active) throw const AppException('Kode promo sudah tidak aktif.');
      if (promo.isExhausted) throw const AppException('Kuota kode promo sudah habis.');
      if ((await tx.get(usedRef)).exists) throw const AppException('Kode ini sudah pernah Anda pakai.');
      final cafeSnap = await tx.get(cafeRef);
      final current = cafeSnap.exists ? CafeModels.cafeFromMap(cafeRef.id, cafeSnap.data()!).premiumUntil : null;

      until = CafeRules.extendPremium(current, _now(), promo.days);
      tx.update(codeRef, {'used': promo.used + 1});
      tx.set(usedRef, {
        'cafeName': customer.displayName,
        'days': promo.days,
        'until': Timestamp.fromDate(until),
        'at': FieldValue.serverTimestamp(),
      });
      tx.set(cafeRef, {
        ..._cafeIdentity(customer.uid, customer.displayName, distributor.root.id),
        'premiumUntil': Timestamp.fromDate(until),
        'lastCode': code,
      }, SetOptions(merge: true));
    });
    return until;
  }

  static Map<String, dynamic> _cafeIdentity(String ownerUid, String name, String distributorId) => {
        'ownerUid': ownerUid,
        'name': name,
        'distributorId': distributorId,
      };
}

/// Stok POS kopi bertambah saat pelanggan menerima pesanan dari distributor.
///
/// Dipakai di dalam transaksi ubah status pesanan: [read] dijalankan di fase baca,
/// [write] di fase tulis; pemanggil menandai pesanan `cafeStockSynced` agar tidak dobel. Bahan dibuat otomatis dari produk distributor (id `dist-{productId}`).
class CafeStockReceipt {
  CafeStockReceipt._(this._cafeRef, this._order, this._lines, this._existing);

  final DocumentReference<Map<String, dynamic>> _cafeRef;
  final SalesOrder _order;
  final List<CartLine> _lines;
  final Map<String, Ingredient?> _existing;

  /// Baris yang masuk ke stok kopi: barang yang dihitung stoknya saja, digabung per produk.
  static List<CartLine> receivableLines(List<CartLine> lines) {
    final byProduct = <String, CartLine>{};
    for (final l in lines.where((l) => l.trackStock && l.qty > 0)) {
      final prev = byProduct[l.productId];
      byProduct[l.productId] = prev == null
          ? l
          : prev.copyWith(
              qty: prev.qty + l.qty,
              // Gabungkan nilai bersih: harga per satuan rata-rata, tanpa diskon terpisah.
              unitPrice: ((prev.net + l.net) / (prev.qty + l.qty)).round(),
              discountAmount: 0,
              packs: const [],
            );
    }
    return byProduct.values.toList();
  }

  static Future<CafeStockReceipt?> read(
    Transaction tx,
    TenantStore distributor,
    SalesOrder order,
    Map<String, dynamic> orderData,
  ) async {
    if (readBool(orderData['cafeStockSynced'])) return null;
    var lines = order.lines;
    final invoiceId = order.invoiceId;
    if (invoiceId != null) {
      final invoice = await tx.get(distributor.col(Collections.invoices).doc(invoiceId));
      final invoiceLines = readMapList(invoice.data()?['lines']).map(SalesModels.lineFromMap).toList();
      if (invoiceLines.isNotEmpty) lines = invoiceLines;
    }
    final receivable = receivableLines(lines);
    final cafeRef = distributor.db.collection(Collections.cafes).doc(order.customerId);
    final existing = <String, Ingredient?>{};
    for (final l in receivable) {
      final id = Ingredient.idForProduct(l.productId);
      final snap = await tx.get(cafeRef.collection(Collections.ingredients).doc(id));
      existing[id] = snap.exists ? CafeModels.ingredientFromMap(id, snap.data()!) : null;
    }
    return CafeStockReceipt._(cafeRef, order, receivable, existing);
  }

  void write(Transaction tx, TenantStore distributor, {required String userId}) {
    tx.set(
      _cafeRef,
      CafeAccountRepository._cafeIdentity(_order.customerId, _order.customerName, distributor.root.id),
      SetOptions(merge: true),
    );
    for (final line in _lines) {
      final id = Ingredient.idForProduct(line.productId);
      final before = _existing[id];
      final after = CafeRules.receive(before, line);
      final ref = _cafeRef.collection(Collections.ingredients).doc(id);
      if (before == null) {
        tx.set(ref, CafeModels.ingredientToMap(after));
      } else {
        tx.update(ref, {'stock': after.stock, 'avgCost': after.avgCost, 'updatedAt': FieldValue.serverTimestamp()});
      }
      tx.set(_cafeRef.collection(Collections.stockMovements).doc(), {
        'ingredientId': id,
        'type': 'receive',
        'qty': after.stock - (before?.stock ?? 0),
        'note': 'Pesanan distributor',
        'refId': _order.id,
        'userId': userId,
        'at': FieldValue.serverTimestamp(),
      });
    }
  }
}
