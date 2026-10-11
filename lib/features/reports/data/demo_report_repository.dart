import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../../sales/data/models/sales_models.dart';
import '../../sales/domain/entities/invoice.dart';
import '../domain/demo_invoice_editor.dart';
import '../../../core/firebase/tenant_store.dart';

/// Ringkasan satu hari data demo.
class DemoDay {
  const DemoDay({required this.key, required this.target, required this.useDemoCatalog});

  final String key;
  final int target;
  final bool useDemoCatalog;
}

/// Data demo per hari, disimpan terpisah total dari koleksi nota asli.
class DemoReportRepository {
  DemoReportRepository(this._store);

  final TenantStore _store;

  FirebaseFirestore get _db => _store.db;

  CollectionReference<Map<String, dynamic>> get _col => _store.col(Collections.demoDays);

  static String keyOf(DateTime d) => DateFormat('yyyyMMdd').format(d);

  Stream<List<Invoice>> watchInvoices(DateTime from, DateTime to) => _col
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('date', isLessThan: Timestamp.fromDate(to))
      .snapshots()
      .map((snap) => [for (final doc in snap.docs) ..._invoices(doc.data())]);

  Stream<Map<String, DemoDay>> watchDays() => _col.snapshots().map(
    (s) => {
      for (final d in s.docs)
        d.id: DemoDay(
          key: d.id,
          target: readInt(d.data()['target']),
          useDemoCatalog: readBool(d.data()['useDemoCatalog']),
        ),
    },
  );

  Future<void> saveDay({
    required DateTime date,
    required int target,
    required int openHour,
    required int closeHour,
    required bool useDemoCatalog,
    required List<Invoice> invoices,
  }) => _col.doc(keyOf(date)).set({
    'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    'target': target,
    'openHour': openHour,
    'closeHour': closeHour,
    'useDemoCatalog': useDemoCatalog,
    'createdAt': FieldValue.serverTimestamp(),
    'invoices': invoices.map(_toMap).toList(),
  });

  /// Mengganti satu nota demo. Total hari itu tetap dijaga <= target.
  Future<void> updateInvoice(Invoice edited) => _db.runTransaction((tx) async {
    final ref = _col.doc(keyOf(edited.createdAt));
    final data = (await tx.get(ref)).data();
    if (data == null) throw const AppException('Data demo hari ini tidak ditemukan.');
    final invoices = _invoices(data);
    DemoInvoiceEditor.ensureWithinTarget(invoices, edited, readInt(data['target']));
    final updated = [for (final i in invoices) i.id == edited.id ? edited : i]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    tx.update(ref, {'invoices': updated.map(_toMap).toList()});
  });

  Future<void> deleteInvoice(Invoice invoice) => _db.runTransaction((tx) async {
    final ref = _col.doc(keyOf(invoice.createdAt));
    final data = (await tx.get(ref)).data();
    if (data == null) return;
    tx.update(ref, {'invoices': _invoices(data).where((i) => i.id != invoice.id).map(_toMap).toList()});
  });

  Future<void> deleteDay(DateTime date) => _col.doc(keyOf(date)).delete();

  List<Invoice> _invoices(Map<String, dynamic> data) => [
    for (final m in readMapList(data['invoices'])) SalesModels.invoiceFromMap(readString(m['id']), m),
  ];

  Map<String, dynamic> _toMap(Invoice i) => {
    'id': i.id,
    'number': i.number,
    'source': i.source.name,
    'customerName': i.customerName,
    'lines': SalesModels.linesToMap(i.lines),
    ...SalesModels.totalsToMap(i.totals),
    'paid': i.paid,
    'change': i.change,
    'paymentMethod': i.paymentMethod?.name,
    'createdAt': Timestamp.fromDate(i.createdAt),
    'createdByName': i.createdByName,
    'voided': false,
  };
}
