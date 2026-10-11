import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../domain/expense.dart';

class FirestoreExpenseRepository implements ExpenseRepository {
  FirestoreExpenseRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection(Collections.expenses);

  @override
  Stream<List<Expense>> watchBetween(DateTime from, DateTime to) => _col
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThan: Timestamp.fromDate(to))
          .snapshots()
          .map((snap) {
        final list = snap.docs
            .map((d) => Expense(
                  id: d.id,
                  date: readDate(d.data()['date']),
                  category: readString(d.data()['category']),
                  amount: readInt(d.data()['amount']),
                  note: readString(d.data()['note']),
                  createdByName: readString(d.data()['createdByName']),
                ))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  @override
  Future<void> save(Expense e, {required String userId, required String userName}) {
    final data = {
      'date': Timestamp.fromDate(e.date),
      'category': e.category,
      'amount': e.amount,
      'note': e.note,
      'updatedBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (e.id.isEmpty) {
      return _col.add({...data, 'createdBy': userId, 'createdByName': userName, 'createdAt': FieldValue.serverTimestamp()});
    }
    return _col.doc(e.id).update(data);
  }
}
