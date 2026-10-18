import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/domain/services/price_suggestion.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';

void main() {
  test('saran harga jual = HPP + margin, dibulatkan ke atas', () {
    // 50 @ 10.000 + 30 @ 15.000 → HPP 11.875; margin 20% → 14.250 → 14.500.
    expect(PriceSuggestion.suggest(11875, 20), 14500);
    expect(PriceSuggestion.suggest(11875, 20, roundTo: 100), 14300);
    expect(PriceSuggestion.suggest(11875, 20, roundTo: 1000), 15000);
    expect(PriceSuggestion.suggest(10000, 20), 12000);
    expect(PriceSuggestion.suggest(0, 20), 0);
  });

  test('pengaturan bawaan: margin 20%, bulat ke 500', () {
    expect(const StoreSettings().suggestPrice(11875), 14500);
  });

  test('margin harga jual terhadap modal', () {
    expect(PriceSuggestion.marginOf(12000, 10000), 20);
    expect(PriceSuggestion.marginOf(9000, 10000), -10);
    expect(PriceSuggestion.marginOf(9000, 0), isNull);
  });

  test('barcode dobel ditemukan, kecuali produk itu sendiri / kosong', () {
    const products = [
      Product(id: 'a', name: 'Kopi A', barcode: '899123', sellPrice: 1),
      Product(id: 'b', name: 'Teh', sellPrice: 1),
    ];
    expect(BarcodeRules.owner(products, ' 899123 ')?.id, 'a');
    expect(BarcodeRules.owner(products, '899123', excludeId: 'a'), isNull);
    expect(BarcodeRules.owner(products, ''), isNull);
    expect(BarcodeRules.owner(products, '111'), isNull);
  });
}
