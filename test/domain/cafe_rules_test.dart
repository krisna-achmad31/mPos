import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/viewmodel/action_view_model.dart';
import 'package:mpos/features/cafe/data/cafe_account_repository.dart';
import 'package:mpos/features/cafe/domain/cafe.dart';
import 'package:mpos/features/cafe/domain/cafe_rules.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/sales/domain/entities/cart_line.dart';

CartLine line(String id, int qty, {int price = 20000, int discount = 0, bool trackStock = true, String unit = 'pack'}) =>
    CartLine(
      productId: id,
      name: 'Produk $id',
      unit: unit,
      qty: qty,
      unitPrice: price,
      priceType: PriceType.retail,
      trackStock: trackStock,
      discountAmount: discount,
    );

void main() {
  const kopi = Ingredient(id: 'kopi', name: 'Biji kopi', unit: 'gram', stock: 1000, avgCost: 150);
  const susu = Ingredient(id: 'susu', name: 'Susu UHT', unit: 'ml', stock: 250, avgCost: 16);
  final ingredients = {'kopi': kopi, 'susu': susu};
  const latte = Recipe(menuId: 'latte', lines: [RecipeLine(ingredientId: 'kopi', qty: 18), RecipeLine(ingredientId: 'susu', qty: 200)]);
  const espresso = Recipe(menuId: 'espresso', lines: [RecipeLine(ingredientId: 'kopi', qty: 18)]);

  group('pemakaian bahan dari resep', () {
    test('qty menu × takaran, digabung antar menu; menu tanpa resep tidak memakai bahan', () {
      final usage = CafeRules.usage(
        [line('latte', 2, trackStock: false), line('espresso', 1, trackStock: false), line('air', 3, trackStock: false)],
        {'latte': latte, 'espresso': espresso},
      );
      expect(usage, {'kopi': 54.0, 'susu': 400.0});
    });

    test('stok kurang disebutkan per bahan', () {
      final short = CafeRules.shortages({'kopi': 54, 'susu': 400}, ingredients);
      expect(short, ['Susu UHT (butuh 400 ml, sisa 250 ml)']);
    });

    test('bahan resep yang sudah dihapus dianggap kurang', () {
      expect(CafeRules.shortages({'gula': 10}, ingredients).single, contains('dihapus'));
    });

    test('HPP per porsi dari HPP rata-rata bahan', () {
      expect(CafeRules.menuCost(latte, ingredients), 18 * 150 + 200 * 16);
      expect(CafeRules.menuCost(null, ingredients), 0);
    });
  });

  group('stok masuk dari distributor', () {
    test('bahan baru mengikuti produk distributor, HPP = harga bersih per satuan', () {
      final i = CafeRules.receive(null, line('arabika', 2, price: 185000, discount: 10000));
      expect(i.id, 'dist-arabika');
      expect(i.unit, 'pack');
      expect(i.stock, 2);
      expect(i.avgCost, (370000 - 10000) / 2);
      expect(i.sourceProductId, 'arabika');
    });

    test('dengan konversi 1 pack = 1000 gram: stok dalam gram, HPP rata-rata tertimbang', () {
      const existing = Ingredient(id: 'dist-arabika', name: 'Arabika', unit: 'gram', purchaseUnit: 'pack', perPurchase: 1000, stock: 500, avgCost: 150);
      final i = CafeRules.receive(existing, line('arabika', 1, price: 180000));
      expect(i.stock, 1500);
      expect(i.avgCost, closeTo((500 * 150 + 1000 * 180) / 1500, 1e-9));
    });

    test('stok minus tidak ikut menurunkan HPP rata-rata', () {
      const existing = Ingredient(id: 'x', name: 'X', unit: 'pcs', stock: -3, avgCost: 1000);
      final i = CafeRules.receive(existing, line('x', 10, price: 2000));
      expect(i.stock, 7);
      expect(i.avgCost, 2000);
    });

    test('baris nota digabung per produk; barang tanpa stok diabaikan', () {
      final lines = CafeStockReceipt.receivableLines([
        line('a', 2, price: 10000),
        line('a', 3, price: 10000, discount: 5000),
        line('jasa', 1, trackStock: false),
      ]);
      expect(lines, hasLength(1));
      expect(lines.single.qty, 5);
      expect(lines.single.net, 45000);
    });
  });

  test('ubah konversi menskalakan stok & HPP, nilai stok tetap', () {
    const i = Ingredient(id: 'x', name: 'Arabika', unit: 'pack', stock: 2, avgCost: 180000);
    final converted = CafeRules.changeConversion(i, unit: 'gram', perPurchase: 1000);
    expect(converted.stock, 2000);
    expect(converted.avgCost, 180);
    expect(converted.stockValue, i.stockValue);
  });

  group('premium', () {
    final now = DateTime(2026, 10, 12, 9);

    test('aktif: diperpanjang dari tanggal berakhir', () {
      expect(CafeRules.extendPremium(DateTime(2026, 10, 20, 9), now, 30), DateTime(2026, 11, 19, 9));
    });

    test('belum / sudah berakhir: dihitung dari sekarang', () {
      expect(CafeRules.extendPremium(null, now, 7), DateTime(2026, 10, 19, 9));
      expect(CafeRules.extendPremium(DateTime(2026, 1, 1), now, 7), DateTime(2026, 10, 19, 9));
    });

    test('status premium dan kuota kode', () {
      expect(Cafe(id: 'c', name: 'K', distributorId: 'd', premiumUntil: DateTime(2026, 10, 13)).isPremium(now), isTrue);
      expect(const Cafe(id: 'c', name: 'K', distributorId: 'd').isPremium(now), isFalse);
      expect(const PremiumCode(code: 'A', days: 30, maxUses: 2, used: 2).usable, isFalse);
      expect(const PremiumCode(code: 'A', days: 30, used: 99).usable, isTrue);
    });

    test('kode dinormalisasi huruf besar tanpa spasi / tanda', () {
      expect(CafeRules.normalizeCode(' kopi-30 x'), 'KOPI30X');
    });
  });

  test('nomor struk urut per hari', () {
    expect(CafeRules.receiptNumber('20261012', 7), 'K-20261012-0007');
  });

  test('angka takaran tanpa nol di belakang koma', () {
    expect(formatQty(18), '18');
    expect(formatQty(2.5), '2,5');
    expect(formatQty(1 / 3), '0,33');
  });

  test('pesan error transaksi web dibersihkan', () {
    expect(cleanErrorMessage('Error: Dart exception: Kode ini sudah pernah Anda pakai.'), 'Kode ini sudah pernah Anda pakai.');
    expect(cleanErrorMessage('Stok kurang'), isNull);
  });
}
