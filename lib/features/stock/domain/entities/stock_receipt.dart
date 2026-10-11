import 'package:equatable/equatable.dart';

class StockReceiptItem extends Equatable {
  const StockReceiptItem({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.buyPrice,
  });

  final String productId;
  final String productName;
  final int qty;
  final int buyPrice;

  int get total => qty * buyPrice;

  StockReceiptItem copyWith({int? qty, int? buyPrice}) => StockReceiptItem(
        productId: productId,
        productName: productName,
        qty: qty ?? this.qty,
        buyPrice: buyPrice ?? this.buyPrice,
      );

  @override
  List<Object?> get props => [productId, productName, qty, buyPrice];
}

enum ReceiptStatus { active, pendingChange }

/// Dokumen stok masuk (penerimaan barang dari supplier).
class StockReceipt extends Equatable {
  const StockReceipt({
    required this.id,
    required this.supplier,
    required this.docNo,
    required this.date,
    required this.items,
    this.createdBy = '',
    this.createdByName = '',
    this.status = ReceiptStatus.active,
  });

  final String id;
  final String supplier;
  final String docNo;
  final DateTime date;
  final List<StockReceiptItem> items;
  final String createdBy;
  final String createdByName;
  final ReceiptStatus status;

  int get total => items.fold(0, (sum, i) => sum + i.total);

  bool get isLocked => status == ReceiptStatus.pendingChange;

  @override
  List<Object?> get props => [id, supplier, docNo, date, items, createdBy, createdByName, status];
}
