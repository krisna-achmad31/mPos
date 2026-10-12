import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/viewmodel/action_view_model.dart';
import '../../auth/auth_providers.dart';
import '../../pricing/domain/services/pricing_service.dart';
import '../../products/domain/entities/product.dart';
import '../../sales/domain/entities/cart_line.dart';
import '../../sales/domain/entities/invoice.dart';
import '../../sales/domain/services/sale_calculator.dart';
import '../../sales/sales_providers.dart';
import '../../settings/domain/store_settings.dart';
import '../../settings/settings_providers.dart';
import '../cafe_providers.dart';
import '../domain/cafe.dart';
import '../domain/cafe_rules.dart';
import '../printing/bluetooth_printer.dart';
import '../printing/receipt_printer.dart';

final receiptPrinterProvider = Provider((ref) => ReceiptPrinter());

/// Kop struk POS kopi. Sebelum diatur, nama kedai memakai nama toko pelanggan (bukan "Toko Saya").
final cafeReceiptStoreProvider = FutureProvider<StoreSettings>((ref) async {
  final s = await ref.watch(storeSettingsProvider.future);
  if (s.storeName.trim().isNotEmpty && s.storeName != const StoreSettings().storeName) return s;
  final cafeName = ref.watch(myCafeProvider).value?.name ?? '';
  return s.copyWith(storeName: cafeName.isNotEmpty ? cafeName : ref.watch(currentUserProvider).displayName);
});

/// Keranjang kasir POS kopi. Harga menu selalu harga normal (tanpa grosir / kemasan).
class CafeCartViewModel extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  void add(Product menu) {
    final i = state.indexWhere((l) => l.productId == menu.id);
    if (i >= 0) return setQty(menu.id, state[i].qty + 1);
    state = [
      ...state,
      CartLine(
        productId: menu.id,
        name: menu.name,
        unit: menu.unit,
        qty: 1,
        unitPrice: menu.sellPrice,
        priceType: PriceType.retail,
        trackStock: false,
      ),
    ];
  }

  void setQty(String menuId, int qty) => state = [
        for (final l in state)
          if (l.productId != menuId) l else if (qty > 0) l.copyWith(qty: qty),
      ];

  void clear() => state = const [];
}

final cafeCartProvider = NotifierProvider<CafeCartViewModel, List<CartLine>>(CafeCartViewModel.new);

/// Bahan yang kurang untuk isi keranjang saat ini (peringatan sebelum bayar).
final cafeCartShortagesProvider = Provider<List<String>>((ref) {
  final recipes = ref.watch(recipesProvider).value ?? const {};
  return CafeRules.shortages(CafeRules.usage(ref.watch(cafeCartProvider), recipes), ref.watch(ingredientMapProvider));
});

/// Semua aksi tulis POS kopi (kasir, menu, bahan, pengaturan, premium).
class CafeActionsViewModel extends ActionViewModel {
  /// Struk terakhir yang tersimpan dari kasir.
  String? lastInvoiceId;

  Future<bool> checkout({
    required String customerName,
    required PaymentMethod method,
    required int amountGiven,
  }) =>
      run(() async {
        final settings = await readReady(cafeSettingsProvider.future);
        final store = await readReady(storeSettingsProvider.future);
        lastInvoiceId = await ref.read(cafeRepositoryProvider).createSale(
              lines: ref.read(cafeCartProvider),
              customerName: customerName,
              taxPercent: store.effectiveTax,
              method: method,
              amountGiven: amountGiven,
              allowNegativeStock: settings.allowNegativeStock,
              by: ref.read(currentUserProvider),
            );
        ref.read(cafeCartProvider.notifier).clear();
      });

  Future<bool> saveMenu(Product menu, Recipe recipe) => run(() async {
        final cost = CafeRules.menuCost(recipe, ref.read(ingredientMapProvider));
        await ref.read(cafeRepositoryProvider).saveMenu(menu, recipe, portionCost: cost);
      });

  Future<bool> setMenuActive(Product menu, bool active) =>
      run(() => ref.read(cafeRepositoryProvider).saveMenu(
            menu.copyWith(active: active),
            ref.read(recipesProvider).value?[menu.id] ?? Recipe(menuId: menu.id),
            portionCost: CafeRules.menuCost(ref.read(recipesProvider).value?[menu.id], ref.read(ingredientMapProvider)),
          ));

  Future<bool> saveIngredient(Ingredient ingredient) =>
      run(() => ref.read(cafeRepositoryProvider).saveIngredient(ingredient, by: ref.read(currentUserProvider)));

  Future<bool> addStock(String id, double qty, int totalCost, String note) => run(
        () => ref
            .read(cafeRepositoryProvider)
            .changeStock(id, added: qty, totalCost: totalCost, note: note, by: ref.read(currentUserProvider)),
      );

  Future<bool> countStock(String id, double counted, String note) => run(
        () => ref.read(cafeRepositoryProvider).changeStock(id, counted: counted, note: note, by: ref.read(currentUserProvider)),
      );

  Future<bool> deleteIngredient(String id) => run(() => ref.read(cafeRepositoryProvider).deleteIngredient(id));

  Future<bool> saveSettings(CafeSettings settings) => run(() => ref.read(cafeRepositoryProvider).saveSettings(settings));

  /// Kop & footer struk di `cafes/{id}/settings/store`. Tidak memakai SettingsViewModel karena
  /// itu ikut mengganti nama distributor.
  Future<bool> saveStoreSettings(StoreSettings settings) => run(() => ref.read(settingsRepositoryProvider).save(settings));

  // ------------------------------------------------------------- Premium

  /// Customer memakai kode promo dari distributornya.
  Future<bool> redeem(String code) => run(() async {
        await ref.read(cafeAccountRepositoryProvider).redeem(
              ref.read(distributorStoreProvider),
              code,
              customer: ref.read(currentUserProvider),
            );
      });

  Future<bool> createCode(PremiumCode code) => run(
        () => ref
            .read(cafeAccountRepositoryProvider)
            .createCode(ref.read(distributorStoreProvider), code, by: ref.read(currentUserProvider)),
      );

  Future<bool> setCodeActive(PremiumCode code, bool active) =>
      run(() => ref.read(cafeAccountRepositoryProvider).setCodeActive(ref.read(distributorStoreProvider), code.code, active));
}

final cafeActionsViewModelProvider =
    NotifierProvider<CafeActionsViewModel, AsyncValue<void>>(CafeActionsViewModel.new);

/// Cetak struk; dipisah dari aksi lain agar gagal cetak tidak dianggap gagal transaksi.
class ReceiptPrintViewModel extends ActionViewModel {
  /// Pesan error aksi terakhir, untuk layar yang sudah ditutup saat cetak selesai.
  String get errorText => '${state.error ?? ''}';

  Future<bool> printInvoice(Invoice invoice, {bool reprint = false}) => run(() async {
        await ref.read(receiptPrinterProvider).print(
              invoice: invoice,
              store: await readReady(cafeReceiptStoreProvider.future),
              settings: await readReady(cafeSettingsProvider.future),
              reprint: reprint,
            );
      });

  /// Mencetak struk yang baru tersimpan begitu datanya terbaca dari database.
  Future<bool> printById(String invoiceId) => run(() async {
        final invoice = await ref.read(salesRepositoryProvider).watchInvoice(invoiceId).firstWhere((i) => i != null);
        await ref.read(receiptPrinterProvider).print(
              invoice: invoice!,
              store: await readReady(cafeReceiptStoreProvider.future),
              settings: await readReady(cafeSettingsProvider.future),
            );
      });

  Future<bool> printTest(CafeSettings settings) => run(() async {
        await ref.read(receiptPrinterProvider).printTest(store: await readReady(cafeReceiptStoreProvider.future), settings: settings);
      });

  /// Printer Bluetooth yang sudah dipasangkan; kosong bila gagal (pesan error ada di state).
  Future<List<PrinterDevice>> pairedDevices() async {
    var devices = <PrinterDevice>[];
    await run(() async => devices = await ref.read(receiptPrinterProvider).pairedDevices());
    return devices;
  }
}

final receiptPrintViewModelProvider =
    NotifierProvider<ReceiptPrintViewModel, AsyncValue<void>>(ReceiptPrintViewModel.new);
