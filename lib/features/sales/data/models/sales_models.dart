import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_parsing.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/services/sale_calculator.dart';

abstract final class SalesModels {
  static Map<String, dynamic> lineToMap(CartLine l) => {
        'productId': l.productId,
        'name': l.name,
        'unit': l.unit,
        'qty': l.qty,
        'unitPrice': l.unitPrice,
        'priceType': l.priceType.name,
        'trackStock': l.trackStock,
        'discountAmount': l.discountAmount,
        'discountId': l.discountId,
        'discountLabel': l.discountLabel,
        'packs': [
          for (final p in l.packs) {'name': p.name, 'count': p.count, 'contents': p.contents, 'price': p.price},
        ],
      };

  static CartLine lineFromMap(Map<String, dynamic> m) => CartLine(
        productId: readString(m['productId']),
        name: readString(m['name']),
        unit: readString(m['unit']),
        qty: readInt(m['qty']),
        unitPrice: readInt(m['unitPrice']),
        priceType: PriceType.values.firstWhere((t) => t.name == m['priceType'], orElse: () => PriceType.retail),
        trackStock: readBool(m['trackStock'], fallback: true),
        discountAmount: readInt(m['discountAmount']),
        discountId: readNullableString(m['discountId']),
        discountLabel: readString(m['discountLabel']),
        packs: [
          for (final p in readMapList(m['packs']))
            PackUsage(
              name: readString(p['name']),
              count: readInt(p['count']),
              contents: readInt(p['contents']),
              price: readInt(p['price']),
            ),
        ],
      );

  static List<Map<String, dynamic>> linesToMap(List<CartLine> lines) => lines.map(lineToMap).toList();

  static SalesOrder orderFromMap(String id, Map<String, dynamic> m) => SalesOrder(
        id: id,
        customerId: readString(m['customerId']),
        customerName: readString(m['customerName']),
        address: readString(m['address']),
        lines: readMapList(m['lines']).map(lineFromMap).toList(),
        status: OrderStatus.fromName(m['status'] as String?),
        createdAt: readDate(m['createdAt']),
        note: readString(m['note']),
        invoiceId: readNullableString(m['invoiceId']),
        cancelReason: readString(m['cancelReason']),
        courierId: readNullableString(m['courierId']),
        courierName: readString(m['courierName']),
      );

  static PaymentMethod? methodFromName(Object? name) =>
      PaymentMethod.values.where((m) => m.name == name).firstOrNull;

  static Invoice invoiceFromMap(String id, Map<String, dynamic> m) => Invoice(
        id: id,
        number: readString(m['number']),
        source: m['source'] == 'pos' ? InvoiceSource.pos : InvoiceSource.online,
        customerId: readNullableString(m['customerId']),
        customerName: readString(m['customerName']),
        orderId: readNullableString(m['orderId']),
        salesName: readString(m['salesName']),
        lines: readMapList(m['lines']).map(lineFromMap).toList(),
        totals: SaleTotals(
          subtotal: readInt(m['subtotal']),
          itemDiscount: readInt(m['itemDiscount']),
          orderDiscount: readInt(m['orderDiscount']),
          taxPercent: readDouble(m['taxPercent']),
          tax: readInt(m['tax']),
          total: readInt(m['total']),
        ),
        paid: readInt(m['paid']),
        change: readInt(m['change']),
        paymentMethod: methodFromName(m['paymentMethod']),
        createdAt: readDate(m['createdAt']),
        createdByName: readString(m['createdByName']),
        voided: readBool(m['voided']),
      );

  static Map<String, dynamic> totalsToMap(SaleTotals t) => {
        'subtotal': t.subtotal,
        'itemDiscount': t.itemDiscount,
        'orderDiscount': t.orderDiscount,
        'taxPercent': t.taxPercent,
        'tax': t.tax,
        'total': t.total,
      };

  static PaymentRecord paymentFromMap(String id, Map<String, dynamic> m) => PaymentRecord(
        id: id,
        invoiceId: readString(m['invoiceId']),
        amount: readInt(m['amount']),
        method: methodFromName(m['method']) ?? PaymentMethod.cash,
        at: readDate(m['at']),
        byName: readString(m['byName']),
      );

  static InvoiceCost costFromMap(String id, Map<String, dynamic> m) => InvoiceCost(
        invoiceId: id,
        totalCost: readInt(m['totalCost']),
        createdAt: readDate(m['createdAt']),
        voided: readBool(m['voided']),
      );

  static Timestamp ts(DateTime d) => Timestamp.fromDate(d);
}
