import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/stock/domain/entities/stock_receipt.dart';
import 'package:mpos/features/stock/domain/services/stock_calculator.dart';

void main() {
  test('HPP dihitung ulang saat stok masuk dihapus', () {
    // Kebalikan contoh averageCost: 10 @10.000 + 10 @12.000 = 20 @11.000.
    expect(
      StockCalculator.hppAfterRemoval(currentStock: 20, currentHpp: 11000, removedQty: 10, removedPrice: 12000),
      10000,
    );
    // Stok habis setelah ditarik: HPP terakhir dipertahankan.
    expect(
      StockCalculator.hppAfterRemoval(currentStock: 10, currentHpp: 11000, removedQty: 10, removedPrice: 12000),
      11000,
    );
    // Nilai sisa tidak masuk akal (barang mahal sudah banyak terjual): HPP dipertahankan.
    expect(
      StockCalculator.hppAfterRemoval(currentStock: 12, currentHpp: 1000, removedQty: 10, removedPrice: 50000),
      1000,
    );
  });

  test('HPP rata-rata tertimbang', () {
    expect(
      StockCalculator.averageCost(currentStock: 10, currentHpp: 10000, incomingQty: 10, incomingPrice: 12000),
      11000,
    );
    expect(StockCalculator.averageCost(currentStock: 0, currentHpp: 0, incomingQty: 5, incomingPrice: 9000), 9000);
  });

  test('pratinjau HPP setelah dokumen stok masuk disimpan', () {
    const items = [
      StockReceiptItem(productId: 'a', productName: 'A', qty: 30, buyPrice: 15000),
      StockReceiptItem(productId: 'b', productName: 'B', qty: 5, buyPrice: 1),
    ];
    expect(StockCalculator.projectedHpp(productId: 'a', currentStock: 50, currentHpp: 10000, items: items), 11875);
    // Dua baris produk sama dengan harga beda dihitung berurutan.
    expect(
      StockCalculator.projectedHpp(
        productId: 'a',
        currentStock: 0,
        currentHpp: 0,
        items: [items[0], items[0].copyWith(buyPrice: 10000)],
      ),
      12500,
    );
    expect(StockCalculator.projectedHpp(productId: 'c', currentStock: 3, currentHpp: 700, items: items), 700);
  });

  test('selisih qty koreksi stok masuk per produk', () {
    const a = StockReceiptItem(productId: 'a', productName: 'A', qty: 10, buyPrice: 1);
    const b = StockReceiptItem(productId: 'b', productName: 'B', qty: 5, buyPrice: 1);
    final deltas = StockCalculator.deltas([a, b], [a.copyWith(qty: 8)]);
    expect(deltas, {'a': -2, 'b': -5});
  });
}
