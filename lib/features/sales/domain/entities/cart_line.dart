import 'package:equatable/equatable.dart';

import '../../../pricing/domain/services/pricing_service.dart';

class CartLine extends Equatable {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    required this.priceType,
    required this.trackStock,
    this.discountAmount = 0,
    this.discountId,
    this.discountLabel = '',
  });

  final String productId;
  final String name;
  final String unit;
  final int qty;
  final int unitPrice;
  final PriceType priceType;
  final bool trackStock;

  /// Diisi saat nota dibuat (harga khusus / promo).
  final int discountAmount;
  final String? discountId;
  final String discountLabel;

  int get gross => unitPrice * qty;

  int get net => gross - discountAmount;

  CartLine copyWith({
    int? qty,
    int? unitPrice,
    PriceType? priceType,
    int? discountAmount,
    String? discountId,
    String? discountLabel,
  }) =>
      CartLine(
        productId: productId,
        name: name,
        unit: unit,
        qty: qty ?? this.qty,
        unitPrice: unitPrice ?? this.unitPrice,
        priceType: priceType ?? this.priceType,
        trackStock: trackStock,
        discountAmount: discountAmount ?? this.discountAmount,
        discountId: discountId ?? this.discountId,
        discountLabel: discountLabel ?? this.discountLabel,
      );

  CartLine withoutDiscount() => CartLine(
        productId: productId,
        name: name,
        unit: unit,
        qty: qty,
        unitPrice: unitPrice,
        priceType: priceType,
        trackStock: trackStock,
      );

  @override
  List<Object?> get props => [productId, qty, unitPrice, priceType, discountAmount, discountId];
}
