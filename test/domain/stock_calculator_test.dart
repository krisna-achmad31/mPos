import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/stock/domain/entities/stock_receipt.dart';
import 'package:mpos/features/stock/domain/services/stock_calculator.dart';

void main() {
  test('HPP rata-rata tertimbang', () {
    expect(
      StockCalculator.averageCost(currentStock: 10, currentHpp: 10000, incomingQty: 10, incomingPrice: 12000),
      11000,
    );
    expect(StockCalculator.averageCost(currentStock: 0, currentHpp: 0, incomingQty: 5, incomingPrice: 9000), 9000);
  });

  test('selisih qty koreksi stok masuk per produk', () {
    const a = StockReceiptItem(productId: 'a', productName: 'A', qty: 10, buyPrice: 1);
    const b = StockReceiptItem(productId: 'b', productName: 'B', qty: 5, buyPrice: 1);
    final deltas = StockCalculator.deltas([a, b], [a.copyWith(qty: 8)]);
    expect(deltas, {'a': -2, 'b': -5});
  });
}
