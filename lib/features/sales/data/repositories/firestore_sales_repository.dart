import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/audit.dart';
import '../../../../core/firebase/collections.dart';
import '../../../../core/firebase/firestore_parsing.dart';
import '../../../../core/firebase/tenant_store.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/repositories/sales_repository.dart';
import '../../domain/services/invoice_number.dart';
import '../../domain/services/sale_calculator.dart';
import '../models/sales_models.dart';

class FirestoreSalesRepository implements SalesRepository {
  FirestoreSalesRepository(this._store, this._now);

  final TenantStore _store;

  FirebaseFirestore get _db => _store.db;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _products => _store.col(Collections.products);
  CollectionReference<Map<String, dynamic>> get _costs => _store.col(Collections.productCosts);
  CollectionReference<Map<String, dynamic>> get _orders => _store.col(Collections.orders);
  CollectionReference<Map<String, dynamic>> get _invoices => _store.col(Collections.invoices);
  CollectionReference<Map<String, dynamic>> get _invoiceCosts => _store.col(Collections.invoiceCosts);
  CollectionReference<Map<String, dynamic>> get _payments => _store.col(Collections.payments);

  // ---------------------------------------------------------------- Pesanan

  @override
  Stream<List<SalesOrder>> watchOrders({String? customerId}) {
    Query<Map<String, dynamic>> query = _orders;
    if (customerId != null) query = query.where('customerId', isEqualTo: customerId);
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => SalesModels.orderFromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<SalesOrder?> watchOrder(String id) =>
      _orders.doc(id).snapshots().map((s) => s.exists ? SalesModels.orderFromMap(s.id, s.data()!) : null);

  @override
  Future<String> placeOrder({required AppUser customer, required List<CartLine> lines, String note = ''}) async {
    if (lines.isEmpty) throw const AppException('Keranjang masih kosong.');
    final orderRef = _orders.doc();

    await _db.runTransaction((tx) async {
      final stock = await _readStock(tx, lines);
      _ensureStock(lines, stock);

      for (final entry in _qtyByProduct(lines).entries) {
        if (!stock.containsKey(entry.key)) continue;
        tx.update(_products.doc(entry.key), {'stock': stock[entry.key]!.qty - entry.value});
        writeStockMovement(_store, tx,
            productId: entry.key,
            type: 'reserve',
            qty: -entry.value,
            refType: Collections.orders,
            refId: orderRef.id,
            userId: customer.uid);
      }
      tx.set(orderRef, {
        'customerId': customer.uid,
        'customerName': customer.displayName,
        'address': customer.address,
        // Harga normal saja: diskon dihitung Owner saat nota dibuat.
        'lines': SalesModels.linesToMap(lines.map((l) => l.withoutDiscount()).toList()),
        'subtotal': lines.fold<int>(0, (s, l) => s + l.gross),
        'status': OrderStatus.pending.name,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return orderRef.id;
  }

  @override
  Future<String> processOrder({
    required SalesOrder order,
    required List<CartLine> pricedLines,
    required OrderDiscount orderDiscount,
    required double taxPercent,
    required AppUser by,
  }) async {
    final invoiceRef = _invoices.doc();
    final now = _now();

    await _db.runTransaction((tx) async {
      final orderSnap = await tx.get(_orders.doc(order.id));
      if (OrderStatus.fromName(orderSnap.data()?['status'] as String?) != OrderStatus.pending) {
        throw const AppException('Pesanan ini sudah diproses atau dibatalkan.');
      }
      final hpp = await _readHpp(tx, pricedLines);
      final number = await _nextNumber(tx, now);

      final totals = SaleCalculator.totals(pricedLines, orderDiscount: orderDiscount, taxPercent: taxPercent);
      _writeInvoice(tx, invoiceRef,
          number: number,
          source: InvoiceSource.online,
          lines: pricedLines,
          totals: totals,
          customerId: order.customerId,
          customerName: order.customerName,
          orderId: order.id,
          salesName: '',
          paid: 0,
          change: 0,
          method: null,
          hpp: hpp,
          by: by);
      tx.update(_orders.doc(order.id), {
        'status': OrderStatus.processing.name,
        'invoiceId': invoiceRef.id,
        'processedAt': FieldValue.serverTimestamp(),
      });
    });
    return invoiceRef.id;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) =>
      _orders.doc(orderId).update({'status': status.name, '${status.name}At': FieldValue.serverTimestamp()});

  @override
  Future<void> cancelOrder({required SalesOrder order, required String reason, required AppUser by}) async {
    if (reason.trim().isEmpty) throw const AppException('Alasan pembatalan wajib diisi.');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_orders.doc(order.id));
      final status = OrderStatus.fromName(snap.data()?['status'] as String?);
      final allowed = by.isOwner ? status.canCancel : status == OrderStatus.pending;
      if (!allowed) throw AppException('Pesanan berstatus ${status.label} tidak bisa dibatalkan.');

      final stock = await _readStock(tx, order.lines);
      for (final entry in _qtyByProduct(order.lines).entries) {
        if (!stock.containsKey(entry.key)) continue;
        tx.update(_products.doc(entry.key), {'stock': stock[entry.key]!.qty + entry.value});
        writeStockMovement(_store, tx,
            productId: entry.key,
            type: 'release',
            qty: entry.value,
            refType: Collections.orders,
            refId: order.id,
            userId: by.uid);
      }
      tx.update(_orders.doc(order.id), {
        'status': OrderStatus.cancelled.name,
        'cancelReason': reason.trim(),
        'cancelledBy': by.uid,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      final invoiceId = order.invoiceId;
      if (invoiceId != null) {
        tx.update(_invoices.doc(invoiceId), {'voided': true});
        tx.update(_invoiceCosts.doc(invoiceId), {'voided': true});
      }
      if (by.isOwner) {
        writeAudit(_store, tx,
            userId: by.uid,
            userName: by.name,
            action: 'cancel',
            entity: Collections.orders,
            entityId: order.id,
            after: reason.trim());
      }
    });
  }

  // ------------------------------------------------------------ Kasir (POS)

  @override
  Future<String> createPosSale({
    required List<CartLine> pricedLines,
    required String? customerId,
    required String customerName,
    required String salesName,
    required OrderDiscount orderDiscount,
    required double taxPercent,
    required PaymentMethod method,
    required int amountGiven,
    required AppUser by,
  }) async {
    if (pricedLines.isEmpty) throw const AppException('Keranjang masih kosong.');
    final totals = SaleCalculator.totals(pricedLines, orderDiscount: orderDiscount, taxPercent: taxPercent);
    final payment = SaleCalculator.pay(total: totals.total, method: method, amount: amountGiven);
    final invoiceRef = _invoices.doc();
    final now = _now();

    await _db.runTransaction((tx) async {
      final stock = await _readStock(tx, pricedLines);
      _ensureStock(pricedLines, stock);
      final hpp = await _readHpp(tx, pricedLines);
      final number = await _nextNumber(tx, now);

      for (final entry in _qtyByProduct(pricedLines).entries) {
        if (!stock.containsKey(entry.key)) continue;
        tx.update(_products.doc(entry.key), {'stock': stock[entry.key]!.qty - entry.value});
        writeStockMovement(_store, tx,
            productId: entry.key,
            type: 'out',
            qty: -entry.value,
            refType: Collections.invoices,
            refId: invoiceRef.id,
            userId: by.uid);
      }
      _writeInvoice(tx, invoiceRef,
          number: number,
          source: InvoiceSource.pos,
          lines: pricedLines,
          totals: totals,
          customerId: customerId,
          customerName: customerName,
          orderId: null,
          salesName: salesName,
          paid: payment.paid,
          change: payment.change,
          method: method,
          hpp: hpp,
          by: by);
      if (payment.paid > 0) {
        _writePayment(tx, invoiceRef.id, customerId, payment.paid, method, by);
      }
      if (pricedLines.any((l) => l.priceType.name == 'manual')) {
        writeAudit(_store, tx,
            userId: by.uid,
            userName: by.name,
            action: 'manual_price',
            entity: Collections.invoices,
            entityId: invoiceRef.id,
            after: SalesModels.linesToMap(pricedLines.where((l) => l.priceType.name == 'manual').toList()));
      }
    });
    return invoiceRef.id;
  }

  // ------------------------------------------------------ Nota & pembayaran

  @override
  Stream<List<Invoice>> watchInvoices({String? customerId, DateTime? from, DateTime? to}) {
    Query<Map<String, dynamic>> query = _invoices;
    if (customerId != null) {
      query = query.where('customerId', isEqualTo: customerId);
    } else {
      if (from != null) query = query.where('createdAt', isGreaterThanOrEqualTo: SalesModels.ts(from));
      if (to != null) query = query.where('createdAt', isLessThan: SalesModels.ts(to));
    }
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => SalesModels.invoiceFromMap(d.id, d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Stream<Invoice?> watchInvoice(String id) =>
      _invoices.doc(id).snapshots().map((s) => s.exists ? SalesModels.invoiceFromMap(s.id, s.data()!) : null);

  @override
  Stream<List<PaymentRecord>> watchPayments(String invoiceId, {String? customerId}) {
    var query = _payments.where('invoiceId', isEqualTo: invoiceId);
    if (customerId != null) query = query.where('customerId', isEqualTo: customerId);
    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => SalesModels.paymentFromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.at.compareTo(b.at));
      return list;
    });
  }

  @override
  Stream<List<PaymentRecord>> watchPaymentsBetween(DateTime from, DateTime to) => _payments
      .where('at', isGreaterThanOrEqualTo: SalesModels.ts(from))
      .where('at', isLessThan: SalesModels.ts(to))
      .snapshots()
      .map((snap) => snap.docs.map((d) => SalesModels.paymentFromMap(d.id, d.data())).toList());

  @override
  Stream<List<InvoiceCost>> watchInvoiceCosts(DateTime from, DateTime to) => _invoiceCosts
      .where('createdAt', isGreaterThanOrEqualTo: SalesModels.ts(from))
      .where('createdAt', isLessThan: SalesModels.ts(to))
      .snapshots()
      .map((snap) => snap.docs.map((d) => SalesModels.costFromMap(d.id, d.data())).toList());

  @override
  Future<void> addPayment({
    required Invoice invoice,
    required int amount,
    required PaymentMethod method,
    required AppUser by,
  }) async {
    if (amount <= 0) throw const AppException('Nominal harus lebih dari 0.');
    await _db.runTransaction((tx) async {
      final ref = _invoices.doc(invoice.id);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || readBool(data['voided'])) throw const AppException('Nota tidak ditemukan atau sudah batal.');
      final total = readInt(data['total']);
      final paid = readInt(data['paid']);
      if (amount > total - paid) throw AppException('Nominal melebihi sisa tagihan (${total - paid}).');

      final newPaid = paid + amount;
      tx.update(ref, {'paid': newPaid, 'paymentStatus': PaymentStatus.of(paid: newPaid, total: total).name});
      _writePayment(tx, invoice.id, invoice.customerId, amount, method, by);
    });
  }

  // --------------------------------------------------------------- Helpers

  Map<String, int> _qtyByProduct(List<CartLine> lines) {
    final result = <String, int>{};
    for (final l in lines.where((l) => l.trackStock)) {
      result[l.productId] = (result[l.productId] ?? 0) + l.qty;
    }
    return result;
  }

  /// Stok terbaru produk yang dihitung stoknya. Produk "tanpa stok" tidak dibaca.
  Future<Map<String, ({int qty, String name})>> _readStock(Transaction tx, List<CartLine> lines) async {
    final result = <String, ({int qty, String name})>{};
    for (final id in _qtyByProduct(lines).keys) {
      final snap = await tx.get(_products.doc(id));
      if (!snap.exists) throw const AppException('Produk tidak ditemukan.');
      final data = snap.data()!;
      if (!readBool(data['trackStock'], fallback: true)) continue;
      result[id] = (qty: readInt(data['stock']), name: readString(data['name']));
    }
    return result;
  }

  void _ensureStock(List<CartLine> lines, Map<String, ({int qty, String name})> stock) {
    for (final entry in _qtyByProduct(lines).entries) {
      final available = stock[entry.key];
      if (available != null && entry.value > available.qty) {
        throw AppException('Stok ${available.name} tersedia hanya ${available.qty}.');
      }
    }
  }

  Future<Map<String, int>> _readHpp(Transaction tx, List<CartLine> lines) async {
    final result = <String, int>{};
    for (final id in lines.map((l) => l.productId).toSet()) {
      final snap = await tx.get(_costs.doc(id));
      result[id] = readInt(snap.data()?['hpp']);
    }
    return result;
  }

  Future<String> _nextNumber(Transaction tx, DateTime now) async {
    final key = InvoiceNumber.dayKey(now);
    final ref = _store.col(Collections.counters).doc('invoice-$key');
    final snap = await tx.get(ref);
    final next = readInt(snap.data()?['seq']) + 1;
    tx.set(ref, {'seq': next});
    return InvoiceNumber.format(now, next);
  }

  void _writeInvoice(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref, {
    required String number,
    required InvoiceSource source,
    required List<CartLine> lines,
    required SaleTotals totals,
    required String? customerId,
    required String customerName,
    required String? orderId,
    required String salesName,
    required int paid,
    required int change,
    required PaymentMethod? method,
    required Map<String, int> hpp,
    required AppUser by,
  }) {
    tx.set(ref, {
      'number': number,
      'source': source.name,
      'customerId': customerId,
      'customerName': customerName,
      'orderId': orderId,
      'salesName': salesName,
      'lines': SalesModels.linesToMap(lines),
      ...SalesModels.totalsToMap(totals),
      'paid': paid,
      'change': change,
      'paymentMethod': method?.name,
      'paymentStatus': PaymentStatus.of(paid: paid, total: totals.total).name,
      'voided': false,
      'createdBy': by.uid,
      'createdByName': by.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // HPP disalin saat nota terbit agar laba tidak berubah bila HPP produk berubah kemudian.
    final totalCost = lines.fold<int>(0, (acc, l) => acc + (hpp[l.productId] ?? 0) * l.qty);
    tx.set(_invoiceCosts.doc(ref.id), {
      'totalCost': totalCost,
      'lines': {for (final l in lines) l.productId: hpp[l.productId] ?? 0},
      'voided': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _writePayment(Transaction tx, String invoiceId, String? customerId, int amount, PaymentMethod method, AppUser by) {
    tx.set(_payments.doc(), {
      'invoiceId': invoiceId,
      'customerId': customerId,
      'amount': amount,
      'method': method.name,
      'byName': by.name,
      'at': FieldValue.serverTimestamp(),
    });
  }
}
