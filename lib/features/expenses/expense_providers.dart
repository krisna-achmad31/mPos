import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/dates.dart';
import '../../core/viewmodel/action_view_model.dart';
import '../auth/auth_providers.dart';
import 'data/firestore_expense_repository.dart';
import 'domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => FirestoreExpenseRepository(ref.watch(firestoreProvider)),
);

/// Pengeluaran dalam satu bulan (parameter: tanggal berapa pun di bulan itu).
final expensesInMonthProvider = StreamProvider.family<List<Expense>, DateTime>(
  (ref, month) => ref.watch(expenseRepositoryProvider).watchBetween(startOfMonth(month), startOfNextMonth(month)),
);

class ExpenseViewModel extends ActionViewModel {
  Future<bool> save(Expense expense) => run(() async {
        if (expense.amount <= 0) throw const AppException('Nominal harus lebih dari 0.');
        if (expense.category.trim().isEmpty) throw const AppException('Kategori wajib diisi.');
        final user = ref.read(currentUserProvider);
        await ref.read(expenseRepositoryProvider).save(expense, userId: user.uid, userName: user.name);
      });
}

final expenseViewModelProvider = NotifierProvider<ExpenseViewModel, AsyncValue<void>>(ExpenseViewModel.new);
