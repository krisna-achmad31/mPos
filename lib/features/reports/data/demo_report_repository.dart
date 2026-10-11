import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../../sales/data/models/sales_models.dart';
import '../../sales/domain/entities/invoice.dart';

/// Data demo per hari, disimpan terpisah total dari koleksi nota asli.
class DemoReportRepository {
  DemoReportRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Collections.demoDays);

  String _key(DateTime d) => DateFormat('yyyyMMdd').format(d);

  Stream<List<Invoice>> watchInvoices(DateTime from, DateTime to) => _col
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('date', isLessThan: Timestamp.fromDate(to))
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              for (final m in readMapList(doc.data()['invoices'])) SalesModels.invoiceFromMap(readString(m['id']), m),
          ]);

  Stream<Set<String>> watchDemoDayKeys() => _col.snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  Future<void> saveDay({
    required DateTime date,
    required int target,
    required int openHour,
    required int closeHour,
    required List<Invoice> invoices,
  }) =>
      _col.doc(_key(date)).set({
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'target': target,
        'openHour': openHour,
        'closeHour': closeHour,
        'createdAt': FieldValue.serverTimestamp(),
        'invoices': [
          for (final i in invoices)
            {
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
            },
        ],
      });

  Future<void> deleteDay(DateTime date) => _col.doc(_key(date)).delete();
}
