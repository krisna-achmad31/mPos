import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/firebase/firestore_parsing.dart';
import '../../domain/entities/change_request.dart';
import '../../domain/entities/stock_receipt.dart';

abstract final class StockModels {
  static StockReceiptItem itemFromMap(Map<String, dynamic> m) => StockReceiptItem(
        productId: readString(m['productId']),
        productName: readString(m['productName']),
        qty: readInt(m['qty']),
        buyPrice: readInt(m['buyPrice']),
      );

  static Map<String, dynamic> itemToMap(StockReceiptItem i) => {
        'productId': i.productId,
        'productName': i.productName,
        'qty': i.qty,
        'buyPrice': i.buyPrice,
      };

  static List<Map<String, dynamic>> itemsToMap(List<StockReceiptItem> items) => items.map(itemToMap).toList();

  static StockReceipt receiptFromMap(String id, Map<String, dynamic> m) => StockReceipt(
        id: id,
        supplier: readString(m['supplier']),
        docNo: readString(m['docNo']),
        date: readDate(m['date']),
        items: readMapList(m['items']).map(itemFromMap).toList(),
        createdBy: readString(m['createdBy']),
        createdByName: readString(m['createdByName']),
        status: m['status'] == 'pending_change' ? ReceiptStatus.pendingChange : ReceiptStatus.active,
      );

  static Map<String, dynamic> receiptToMap(StockReceipt r) => {
        'supplier': r.supplier,
        'docNo': r.docNo,
        'date': Timestamp.fromDate(r.date),
        'items': itemsToMap(r.items),
        'productIds': r.items.map((i) => i.productId).toSet().toList(),
        'total': r.total,
        'createdBy': r.createdBy,
        'createdByName': r.createdByName,
        'status': 'active',
      };

  static ChangeRequest requestFromMap(String id, Map<String, dynamic> m) => ChangeRequest(
        id: id,
        receiptId: readString(m['receiptId']),
        receiptDocNo: readString(m['receiptDocNo']),
        oldItems: readMapList(m['oldItems']).map(itemFromMap).toList(),
        newItems: readMapList(m['newItems']).map(itemFromMap).toList(),
        reason: readString(m['reason']),
        requestedBy: readString(m['requestedBy']),
        requestedByName: readString(m['requestedByName']),
        status: ChangeRequestStatus.values.firstWhere(
          (s) => s.name == m['status'],
          orElse: () => ChangeRequestStatus.pending,
        ),
        createdAt: readDate(m['createdAt']),
        decidedByName: readString(m['decidedByName']),
        decisionNote: readString(m['decisionNote']),
      );
}
