import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/catalog/domain/customer_spending.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/sales/domain/entities/cart_line.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/entities/sales_order.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';

CartLine line(String id, int qty, int price, {int discount = 0}) => CartLine(
      productId: id,
      name: id,
      unit: 'pcs',
      qty: qty,
      unitPrice: price,
      priceType: PriceType.retail,
      trackStock: true,
      discountAmount: discount,
    );

SalesOrder order(String id, DateTime at, List<CartLine> lines, {OrderStatus status = OrderStatus.pending, String? invoiceId}) =>
    SalesOrder(
      id: id,
      customerId: 'c1',
      customerName: 'Kopi Senja',
      address: '',
      lines: lines,
      status: status,
      createdAt: at,
      invoiceId: invoiceId,
    );

void main() {
  final from = DateTime(2026, 10);
  final to = DateTime(2026, 11);
  final categories = {'sirup': 'Sirup', 'kopi': 'Kopi'};

  test('per kategori: invoice dipakai bila ada, pesanan batal & bulan lain diabaikan', () {
    final invLines = [line('sirup', 2, 100000, discount: 20000), line('kopi', 1, 50000)];
    final invoice = Invoice(
      id: 'inv1',
      number: 'INV-1',
      source: InvoiceSource.online,
      customerName: 'Kopi Senja',
      lines: invLines,
      totals: SaleCalculator.totals(invLines),
      paid: 0,
      change: 0,
      createdAt: DateTime(2026, 10, 5),
    );
    final s = CustomerSpendingBuilder.build(
      orders: [
        order('o1', DateTime(2026, 10, 5), [line('sirup', 2, 100000), line('kopi', 1, 50000)],
            status: OrderStatus.processing, invoiceId: 'inv1'),
        order('o2', DateTime(2026, 10, 7), [line('kopi', 3, 50000)]),
        order('o3', DateTime(2026, 10, 8), [line('kopi', 9, 50000)], status: OrderStatus.cancelled),
        order('o4', DateTime(2026, 9, 30), [line('sirup', 1, 100000)]),
      ],
      invoicesById: {'inv1': invoice},
      categoryByProduct: categories,
      from: from,
      to: to,
    );
    expect(s.orderCount, 2);
    expect(s.pendingCount, 1);
    expect(s.total, 230000 + 150000);
    expect(s.itemCount, 6);
    expect(s.byCategory.first.name, 'Kopi');
    expect(s.byCategory.firstWhere((c) => c.name == 'Sirup').amount, 180000);
    expect(s.itemsByCategory['Kopi']!.single.qty, 4);
    expect(s.byDay.length, 31);
  });
}
