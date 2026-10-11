import 'package:equatable/equatable.dart';

/// Pengeluaran operasional di luar produk (listrik, gaji, sewa, dll.).
class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.amount,
    this.note = '',
    this.createdByName = '',
  });

  static const defaultCategories = ['Listrik', 'Air', 'Gaji', 'Sewa', 'Transport', 'Internet', 'Lainnya'];

  final String id;
  final DateTime date;
  final String category;
  final int amount;
  final String note;
  final String createdByName;

  @override
  List<Object?> get props => [id, date, category, amount, note];
}

abstract interface class ExpenseRepository {
  Stream<List<Expense>> watchBetween(DateTime from, DateTime to);

  /// Membuat baru bila id kosong. Pengeluaran tidak dihapus permanen.
  Future<void> save(Expense expense, {required String userId, required String userName});
}
