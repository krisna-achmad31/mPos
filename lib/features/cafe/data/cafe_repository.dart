import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../../../core/firebase/tenant_store.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../products/data/models/product_model.dart';
import '../../products/domain/entities/product.dart';
import '../../sales/data/models/sales_models.dart';
import '../../sales/domain/entities/cart_line.dart';
import '../../sales/domain/services/invoice_number.dart';
import '../../sales/domain/services/sale_calculator.dart';
import '../domain/cafe.dart';
import '../domain/cafe_rules.dart';

/// Pemetaan dokumen Firestore POS kopi.
abstract final class CafeModels {
  static Ingredient ingredientFromMap(String id, Map<String, dynamic> m) => Ingredient(
        id: id,
        name: readString(m['name']),
        unit: readString(m['unit']),
        purchaseUnit: readString(m['purchaseUnit']),
        perPurchase: readDouble(m['perPurchase']) > 0 ? readDouble(m['perPurchase']) : 1,
        stock: readDouble(m['stock']),
        avgCost: readDouble(m['avgCost']),
        minStock: readDouble(m['minStock']),
        sourceProductId: readNullableString(m['sourceProductId']),
      );

  static Map<String, dynamic> ingredientToMap(Ingredient i) => {
        'name': i.name.trim(),
        'unit': i.unit.trim(),
        'purchaseUnit': i.purchaseUnit.trim(),
        'perPurchase': i.perPurchase,
        'stock': i.stock,
        'avgCost': i.avgCost,
        'minStock': i.minStock,
        'sourceProductId': i.sourceProductId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static Recipe recipeFromMap(String menuId, Map<String, dynamic>? m) => Recipe(
        menuId: menuId,
        lines: [
          for (final l in readMapList(m?['lines']))
            RecipeLine(ingredientId: readString(l['ingredientId']), qty: readDouble(l['qty'])),
        ],
      );

  static Map<String, dynamic> recipeToMap(Recipe r) => {
        'lines': [
          for (final l in r.lines) {'ingredientId': l.ingredientId, 'qty': l.qty},
        ],
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static CafeSettings settingsFromMap(Map<String, dynamic>? m) => m == null
      ? const CafeSettings()
      : CafeSettings(
          paperWidth: readInt(m['paperWidth']) == 80 ? 80 : 58,
          printerName: readString(m['printerName']),
          printerAddress: readString(m['printerAddress']),
          autoPrint: readBool(m['autoPrint'], fallback: true),
          allowNegativeStock: readBool(m['allowNegativeStock']),
        );

  static Map<String, dynamic> settingsToMap(CafeSettings s) => {
        'paperWidth': s.paperWidth,
        'printerName': s.printerName,
        'printerAddress': s.printerAddress,
        'autoPrint': s.autoPrint,
        'allowNegativeStock': s.allowNegativeStock,
      };

  static Cafe cafeFromMap(String id, Map<String, dynamic> m) => Cafe(
        id: id,
        name: readString(m['name']),
        distributorId: readString(m['distributorId']),
        premiumUntil: readNullableDate(m['premiumUntil']),
        lastCode: readString(m['lastCode']),
      );

  static PremiumCode codeFromMap(String id, Map<String, dynamic> m) => PremiumCode(
        code: id,
        days: readInt(m['days']),
        maxUses: readInt(m['maxUses']),
        used: readInt(m['used']),
        active: readBool(m['active'], fallback: true),
        note: readString(m['note']),
        createdAt: readNullableDate(m['createdAt']),
      );
}

/// Satu baris riwayat stok bahan.
class IngredientMovement {
  const IngredientMovement({required this.type, required this.qty, required this.at, this.note = '', this.refId = ''});

  /// receive (dari distributor) | sale | in (beli di luar) | adjust (opname / koreksi)
  final String type;
  final double qty;
  final DateTime at;
  final String note;
  final String refId;

  String get label => switch (type) {
        'receive' => 'Diterima dari distributor',
        'sale' => 'Terjual',
        'in' => 'Stok masuk',
        _ => 'Penyesuaian',
      };
}

/// Data operasional satu POS kopi: bahan, resep, struk, pengaturan. Semua di `cafes/{cafeId}`.
class CafeRepository {
  CafeRepository(this._store, this._now) {
    if (!_store.isCafe) throw StateError('CafeRepository butuh store POS kopi');
  }

  final TenantStore _store;
  final DateTime Function() _now;

  FirebaseFirestore get _db => _store.db;

  CollectionReference<Map<String, dynamic>> get _ingredients => _store.col(Collections.ingredients);
  CollectionReference<Map<String, dynamic>> get _recipes => _store.col(Collections.recipes);
  CollectionReference<Map<String, dynamic>> get _products => _store.col(Collections.products);
  CollectionReference<Map<String, dynamic>> get _movements => _store.col(Collections.stockMovements);
  DocumentReference<Map<String, dynamic>> get _settings => _store.col(Collections.settings).doc('cafe');

  // ------------------------------------------------------------------ Bahan

  Stream<List<Ingredient>> watchIngredients() => _ingredients.snapshots().map((snap) {
        final list = [for (final d in snap.docs) CafeModels.ingredientFromMap(d.id, d.data())];
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  Stream<List<IngredientMovement>> watchMovements(String ingredientId) =>
      _movements.where('ingredientId', isEqualTo: ingredientId).snapshots().map((snap) {
        final list = [
          for (final d in snap.docs)
            IngredientMovement(
              type: readString(d.data()['type']),
              qty: readDouble(d.data()['qty']),
              at: readDate(d.data()['at']),
              note: readString(d.data()['note']),
              refId: readString(d.data()['refId']),
            ),
        ];
        list.sort((a, b) => b.at.compareTo(a.at));
        return list;
      });

  /// Bahan baru (id kosong, stok awal dicatat sebagai stok masuk) atau ubah nama / satuan / batas minimum.
  /// Mengubah isi per kemasan bahan lama menskalakan stoknya (lihat [CafeRules.changeConversion]).
  Future<void> saveIngredient(Ingredient ingredient, {required AppUser by}) async {
    if (ingredient.name.trim().isEmpty) throw const AppException('Nama bahan wajib diisi.');
    if (ingredient.unit.trim().isEmpty) throw const AppException('Satuan bahan wajib diisi.');
    if (ingredient.id.isEmpty) {
      final ref = _ingredients.doc();
      final batch = _db.batch()..set(ref, CafeModels.ingredientToMap(ingredient));
      if (ingredient.stock != 0) {
        _movement(batch.set, ref.id, 'in', ingredient.stock, by, note: 'Stok awal');
      }
      await batch.commit();
      return;
    }
    await _db.runTransaction((tx) async {
      final ref = _ingredients.doc(ingredient.id);
      final snap = await tx.get(ref);
      if (!snap.exists) throw const AppException('Bahan tidak ditemukan.');
      final current = CafeModels.ingredientFromMap(snap.id, snap.data()!);
      final converted = current.perPurchase == ingredient.perPurchase
          ? current.copyWith(unit: ingredient.unit)
          : CafeRules.changeConversion(current, unit: ingredient.unit, perPurchase: ingredient.perPurchase);
      tx.update(ref, {
        'name': ingredient.name.trim(),
        'unit': converted.unit.trim(),
        'purchaseUnit': ingredient.purchaseUnit.trim(),
        'perPurchase': converted.perPurchase,
        'stock': converted.stock,
        'avgCost': converted.avgCost,
        'minStock': ingredient.minStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// [added] > 0 = stok masuk (beli di luar distributor) dengan total harga [totalCost];
  /// [counted] diisi = hasil hitung fisik (opname), selisihnya dicatat sebagai penyesuaian.
  Future<void> changeStock(
    String ingredientId, {
    double? added,
    int totalCost = 0,
    double? counted,
    String note = '',
    required AppUser by,
  }) =>
      _db.runTransaction((tx) async {
        final ref = _ingredients.doc(ingredientId);
        final snap = await tx.get(ref);
        if (!snap.exists) throw const AppException('Bahan tidak ditemukan.');
        final i = CafeModels.ingredientFromMap(snap.id, snap.data()!);
        if (added != null) {
          if (added <= 0) throw const AppException('Jumlah stok masuk harus lebih dari 0.');
          final oldStock = i.stock > 0 ? i.stock : 0.0;
          final avg = totalCost <= 0 ? i.avgCost : (oldStock * i.avgCost + totalCost) / (oldStock + added);
          tx.update(ref, {'stock': i.stock + added, 'avgCost': avg, 'updatedAt': FieldValue.serverTimestamp()});
          _movement(tx.set, ingredientId, 'in', added, by, note: note);
        } else if (counted != null) {
          if (counted < 0) throw const AppException('Hasil hitung tidak boleh minus.');
          tx.update(ref, {'stock': counted, 'updatedAt': FieldValue.serverTimestamp()});
          _movement(tx.set, ingredientId, 'adjust', counted - i.stock, by, note: note.isEmpty ? 'Opname' : note);
        }
      });

  Future<void> deleteIngredient(String id) async {
    final used = (await _recipes.get()).docs.any(
      (d) => CafeModels.recipeFromMap(d.id, d.data()).lines.any((l) => l.ingredientId == id),
    );
    if (used) throw const AppException('Bahan masih dipakai di resep. Hapus dari resep dulu.');
    await _ingredients.doc(id).delete();
  }

  // ----------------------------------------------------------- Menu & resep

  Stream<Map<String, Recipe>> watchRecipes() =>
      _recipes.snapshots().map((snap) => {for (final d in snap.docs) d.id: CafeModels.recipeFromMap(d.id, d.data())});

  /// Menyimpan menu (di koleksi `products`, tanpa stok) beserta resepnya. HPP per porsi disalin
  /// ke `product_costs` agar laporan bisa menghitung laba data demo dari menu asli.
  Future<String> saveMenu(Product menu, Recipe recipe, {required int portionCost}) async {
    if (menu.name.trim().isEmpty) throw const AppException('Nama menu wajib diisi.');
    if (menu.sellPrice <= 0) throw const AppException('Harga jual harus lebih dari 0.');
    if (recipe.lines.any((l) => l.qty <= 0)) throw const AppException('Takaran resep harus lebih dari 0.');
    final ref = menu.id.isEmpty ? _products.doc() : _products.doc(menu.id);
    final data = {
      ...ProductModel.toEditableMap(menu.copyWith(trackStock: false, packs: const [], wholesalePrice: 0, wholesaleMinQty: 0)),
      'stock': 0,
      'updatedAt': FieldValue.serverTimestamp(),
      if (menu.id.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
    };
    await (_db.batch()
          ..set(ref, data, SetOptions(merge: true))
          ..set(_recipes.doc(ref.id), CafeModels.recipeToMap(recipe))
          ..set(_store.col(Collections.productCosts).doc(ref.id), {'buyPrice': portionCost, 'hpp': portionCost}))
        .commit();
    return ref.id;
  }

  // ------------------------------------------------------------- Penjualan

  /// Menyimpan struk kasir dan memotong stok bahan sesuai resep, dalam satu transaksi.
  /// Format dokumen sama dengan nota distributor, sehingga laporan & riwayat nota bisa dipakai ulang.
  Future<String> createSale({
    required List<CartLine> lines,
    required String customerName,
    required double taxPercent,
    required PaymentMethod method,
    required int amountGiven,
    required bool allowNegativeStock,
    required AppUser by,
  }) async {
    if (lines.isEmpty) throw const AppException('Keranjang masih kosong.');
    final totals = SaleCalculator.totals(lines, taxPercent: taxPercent);
    final payment = SaleCalculator.pay(total: totals.total, method: method, amount: amountGiven);
    final invoiceRef = _store.col(Collections.invoices).doc();
    final now = _now();

    await _db.runTransaction((tx) async {
      // Semua baca dulu (aturan transaksi Firestore), baru tulis.
      final recipes = <String, Recipe>{};
      for (final id in lines.map((l) => l.productId).toSet()) {
        final snap = await tx.get(_recipes.doc(id));
        recipes[id] = CafeModels.recipeFromMap(id, snap.data());
      }
      final usage = CafeRules.usage(lines, recipes);
      final ingredients = <String, Ingredient>{};
      for (final id in usage.keys) {
        final snap = await tx.get(_ingredients.doc(id));
        if (snap.exists) ingredients[id] = CafeModels.ingredientFromMap(id, snap.data()!);
      }
      final short = CafeRules.shortages(usage, ingredients);
      if (short.isNotEmpty && (!allowNegativeStock || ingredients.length < usage.length)) {
        throw AppException('Stok bahan kurang: ${short.join('; ')}');
      }
      final counterRef = _store.col(Collections.counters).doc('receipt-${InvoiceNumber.dayKey(now)}');
      final seq = readInt((await tx.get(counterRef)).data()?['seq']) + 1;

      tx.set(counterRef, {'seq': seq});
      for (final e in usage.entries) {
        tx.update(_ingredients.doc(e.key), {'stock': ingredients[e.key]!.stock - e.value});
        _movement(tx.set, e.key, 'sale', -e.value, by, refId: invoiceRef.id);
      }
      tx.set(invoiceRef, {
        'number': CafeRules.receiptNumber(InvoiceNumber.dayKey(now), seq),
        'source': 'pos',
        'customerId': null,
        'customerName': customerName.trim(),
        'orderId': null,
        'salesName': by.name,
        'lines': SalesModels.linesToMap(lines),
        ...SalesModels.totalsToMap(totals),
        'paid': payment.paid,
        'change': payment.change,
        'paymentMethod': method.name,
        'paymentStatus': PaymentStatus.of(paid: payment.paid, total: totals.total).name,
        'voided': false,
        'createdBy': by.uid,
        'createdByName': by.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // HPP per porsi saat terjual, agar laba tidak berubah bila harga bahan berubah kemudian.
      tx.set(_store.col(Collections.invoiceCosts).doc(invoiceRef.id), {
        'totalCost': CafeRules.cost(usage, ingredients),
        'lines': {for (final id in recipes.keys) id: CafeRules.menuCost(recipes[id], ingredients)},
        'voided': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(_store.col(Collections.payments).doc(), {
        'invoiceId': invoiceRef.id,
        'customerId': null,
        'amount': payment.paid,
        'method': method.name,
        'byName': by.name,
        'at': FieldValue.serverTimestamp(),
      });
    });
    return invoiceRef.id;
  }

  // ------------------------------------------------------------- Pengaturan

  Stream<CafeSettings> watchSettings() => _settings.snapshots().map((s) => CafeModels.settingsFromMap(s.data()));

  Future<void> saveSettings(CafeSettings settings) => _settings.set(CafeModels.settingsToMap(settings));

  void _movement(
    void Function(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>) set,
    String ingredientId,
    String type,
    double qty,
    AppUser by, {
    String note = '',
    String refId = '',
  }) =>
      set(_movements.doc(), {
        'ingredientId': ingredientId,
        'type': type,
        'qty': qty,
        'note': note,
        'refId': refId,
        'userId': by.uid,
        'at': FieldValue.serverTimestamp(),
      });
}
