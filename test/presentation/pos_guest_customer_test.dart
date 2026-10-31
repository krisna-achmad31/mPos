import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpos/features/auth/auth_providers.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/pricing/pricing_providers.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/product_providers.dart';
import 'package:mpos/features/reports/domain/sales_export.dart';
import 'package:mpos/features/sales/domain/entities/cart_line.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/repositories/sales_repository.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';
import 'package:mpos/features/sales/presentation/viewmodels/pos_view_model.dart';
import 'package:mpos/features/sales/presentation/widgets/pos_customer_field.dart';
import 'package:mpos/features/sales/sales_providers.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';
import 'package:mpos/features/settings/settings_providers.dart';

class _SalesRepository extends Mock implements SalesRepository {
  Invoice? saved;

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
    saved = Invoice(
      id: 'i1',
      number: 'INV-1',
      source: InvoiceSource.pos,
      customerId: customerId,
      customerName: customerName,
      lines: pricedLines,
      totals: SaleCalculator.totals(pricedLines),
      paid: 5000,
      change: 0,
      createdAt: DateTime(2026, 10, 30),
    );
    return 'i1';
  }
}

void main() {
  const customer = AppUser(uid: 'c1', name: 'Pelanggan akun', email: '', role: UserRole.customer);

  testWidgets('nama pembeli tanpa akun dapat ditambahkan, divalidasi dan diedit', (tester) async {
    final container = ProviderContainer(
      overrides: [
        customersProvider.overrideWith((ref) => Stream.value(const [customer])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PosCustomerField())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah pelanggan tanpa akun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pakai nama ini'));
    await tester.pumpAndSettle();
    expect(find.text('Nama pelanggan wajib diisi'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, '  Bu Sari WA  ');
    await tester.tap(find.text('Pakai nama ini'));
    await tester.pumpAndSettle();
    expect(container.read(posViewModelProvider).customerName, 'Bu Sari WA');
    expect(container.read(posViewModelProvider).customer, isNull);
    expect(find.text('Ubah nama pelanggan'), findsOneWidget);
    await tester.tap(find.text('Ubah nama pelanggan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Bu Sari Toko');
    await tester.tap(find.text('Pakai nama ini'));
    await tester.pumpAndSettle();
    expect(container.read(posViewModelProvider).customerName, 'Bu Sari Toko');
    container.read(posViewModelProvider.notifier).setCustomer(null);
    await tester.pumpAndSettle();
    expect(container.read(posViewModelProvider).customerName, 'UMUM');
  });

  test('ganti pelanggan menghapus nama sebelumnya dan mempertahankan field transaksi', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final vm = container.read(posViewModelProvider.notifier);
    vm.setCustomer(customer);
    vm.setGuestCustomer('  Toko Langsung  ');
    vm.setSalesName('Sales A');
    expect(container.read(posViewModelProvider).customerName, 'Toko Langsung');
    expect(container.read(posViewModelProvider).customer, isNull);
    vm.setGuestCustomer('  ');
    expect(container.read(posViewModelProvider).customerName, 'Toko Langsung');
    vm.setCustomer(customer);
    expect(container.read(posViewModelProvider).guestCustomerName, '');
    expect(container.read(posViewModelProvider).customerName, customer.displayName);
    expect(container.read(posViewModelProvider).salesName, 'Sales A');
  });

  testWidgets('checkout meneruskan nama ke nota dan laporan, lalu mereset transaksi', (tester) async {
    const product = Product(id: 'p1', name: 'Fanta', sellPrice: 5000, stock: 10);
    final repository = _SalesRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          const AppUser(uid: 'owner', name: 'Owner', email: '', role: UserRole.owner),
        ),
        productsProvider.overrideWith((ref) => Stream.value(const [product])),
        discountsProvider.overrideWith((ref) => Stream.value(const [])),
        storeSettingsProvider.overrideWith((ref) => Stream.value(const StoreSettings())),
        salesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(productsProvider, (_, _) {});
    container.listen(discountsProvider, (_, _) {});
    container.listen(storeSettingsProvider, (_, _) {});
    await tester.pump();
    final vm = container.read(posViewModelProvider.notifier);
    vm.addProduct(product);
    vm.setGuestCustomer('Bu Sari WA');
    vm.setMethod(PaymentMethod.transfer);
    expect(await vm.checkout(), 'i1');
    expect(repository.saved!.customerId, isNull);
    expect(repository.saved!.customerName, 'Bu Sari WA');
    final rows = SalesExport.rows([repository.saved!], unitCost: (_, _) => 0);
    expect(rows.single.customer, 'Bu Sari WA');
    expect(container.read(posViewModelProvider).customerName, 'UMUM');
    expect(container.read(posViewModelProvider).lines, isEmpty);
  });
}
