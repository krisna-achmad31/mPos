import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpos/core/firebase/tenant_store.dart';
import 'package:mpos/features/auth/auth_providers.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/stock/data/repositories/firestore_stock_repository.dart';
import 'package:mpos/features/stock/domain/entities/stock_receipt.dart';
import 'package:mpos/features/stock/domain/repositories/stock_repository.dart';
import 'package:mpos/features/stock/presentation/views/delete_receipt_button.dart';
import 'package:mpos/features/stock/stock_providers.dart';

class _Store extends Mock implements TenantStore {}

class _Stock extends Mock implements StockRepository {
  int deletions = 0;

  @override
  Future<void> deleteReceipt({required StockReceipt receipt, required AppUser by}) async {
    deletions++;
  }
}

void main() {
  const owner = AppUser(uid: 'o', name: 'Owner', email: '', role: UserRole.owner);
  const spv = AppUser(uid: 's', name: 'SPV', email: '', role: UserRole.spv);
  final receipt = StockReceipt(
    id: 'r1',
    supplier: 'PT Sumber',
    docNo: 'SJ-1',
    date: DateTime(2026, 11, 1),
    items: const [StockReceiptItem(productId: 'p1', productName: 'Fanta', qty: 10, buyPrice: 5000)],
  );

  test('repository menolak non-owner sebelum mengakses database', () async {
    final store = _Store();
    final repository = FirestoreStockRepository(store);
    await expectLater(repository.deleteReceipt(receipt: receipt, by: spv), throwsA(anything));
    verifyZeroInteractions(store);
  });

  testWidgets('SPV tidak melihat tombol hapus', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(spv)],
      child: MaterialApp(home: Scaffold(body: DeleteReceiptButton(receipt: receipt))),
    ));
    expect(find.byTooltip('Hapus stok masuk'), findsNothing);
  });

  testWidgets('owner harus konfirmasi; batal tidak menghapus dokumen', (tester) async {
    final stock = _Stock();
    await tester.pumpWidget(ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(owner), stockRepositoryProvider.overrideWithValue(stock)],
      child: MaterialApp(home: Scaffold(body: DeleteReceiptButton(receipt: receipt))),
    ));
    await tester.tap(find.byTooltip('Hapus stok masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(stock.deletions, 0);
    await tester.tap(find.byTooltip('Hapus stok masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus stok masuk'));
    await tester.pumpAndSettle();
    expect(stock.deletions, 1);
  });
}
