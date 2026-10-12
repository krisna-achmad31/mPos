import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/expenses/domain/expense.dart';
import 'package:mpos/features/reports/domain/report_builder.dart';

void main() {
  test('pengeluaran bulanan dibagi rata per hari per kategori', () {
    final month = DateTime(2026, 10);
    final share = ReportBuilder.dailyShareOfExpenses([
      Expense(id: '1', date: DateTime(2026, 10, 12), category: 'Listrik', amount: 250000),
      Expense(id: '2', date: DateTime(2026, 10, 12), category: 'Internet', amount: 300000),
      Expense(id: '3', date: DateTime(2026, 10, 1), category: 'Listrik', amount: 60000),
    ], month);
    final byCat = {for (final e in share) e.category: e.amount};
    expect(byCat['Listrik'], (310000 / 31).round()); // 10.000
    expect(byCat['Internet'], (300000 / 31).round()); // 9.677
  });

  test('Februari dibagi 28 hari', () {
    final share = ReportBuilder.dailyShareOfExpenses(
      [Expense(id: '1', date: DateTime(2026, 2, 3), category: 'Sewa', amount: 2800000)],
      DateTime(2026, 2),
    );
    expect(share.single.amount, 100000);
  });
}
