import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpos/core/firebase/tenant_store.dart';
import 'package:mpos/features/auth/auth_providers.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/sales/data/repositories/firestore_sales_repository.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/repositories/sales_repository.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';
import 'package:mpos/features/sales/presentation/widgets/delete_invoice_button.dart';
import 'package:mpos/features/sales/sales_providers.dart';

class _Store extends Mock implements TenantStore {}

class _Sales extends Mock implements SalesRepository {
  int deletions = 0;

  @override
  Future<void> deleteInvoice({required String invoiceId, required AppUser by}) async {
    deletions++;
  }
}

void main() {
  const owner = AppUser(uid: 'o', name: 'Owner', email: '', role: UserRole.owner);
  const customer = AppUser(uid: 'c', name: 'Customer', email: '', role: UserRole.customer);
  final invoice = Invoice(
    id: 'i1', number: 'INV-1', source: InvoiceSource.pos, customerName: 'UMUM',
    lines: const [], totals: SaleCalculator.totals(const []), paid: 0, change: 0,
    createdAt: DateTime(2026, 10, 31),
  );

  test('repository menolak non-owner sebelum mengakses database', () async {
    final store = _Store();
    final repository = FirestoreSalesRepository(store, DateTime.now);
    await expectLater(repository.deleteInvoice(invoiceId: 'i1', by: customer), throwsA(anything));
    verifyZeroInteractions(store);
  });

  testWidgets('customer tidak melihat tombol hapus', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(customer)],
      child: MaterialApp(home: Scaffold(body: DeleteInvoiceButton(invoice: invoice))),
    ));
    expect(find.byTooltip('Hapus transaksi'), findsNothing);
  });

  testWidgets('owner harus konfirmasi; batal tidak menghapus transaksi', (tester) async {
    final sales = _Sales();
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(owner), salesRepositoryProvider.overrideWithValue(sales)],
      child: MaterialApp(home: Scaffold(body: DeleteInvoiceButton(invoice: invoice))),
    ));
    await tester.tap(find.byTooltip('Hapus transaksi'));
    await tester.pumpAndSettle();
    expect(sales.deletions, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(sales.deletions, 0);
    await tester.tap(find.byTooltip('Hapus transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus transaksi'));
    await tester.pumpAndSettle();
    expect(sales.deletions, 1);
  });
}
