import 'package:equatable/equatable.dart';

import '../../../pricing/domain/services/pricing_service.dart';
import '../../../products/domain/entities/product.dart';

/// Bagian baris yang dihitung per kemasan, mis. 1 karton isi 20 @Rp1.800.000.
class PackUsage extends Equatable {
  const PackUsage({required this.name, required this.count, required this.contents, required this.price});

  final String name;
  final int count;
  final int contents;
  final int price;

  int get qty => count * contents;

  int get total => count * price;

  @override
  List<Object?> get props => [name, count, contents, price];
}

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
    this.packs = const [],
    this.components = const [],
  });

  final String productId;
  final String name;
  final String unit;
  final int qty;
  final int unitPrice;
  final PriceType priceType;
  final bool trackStock;

  /// Kemasan yang terpakai; sisanya (looseQty) dihitung dengan [unitPrice].
  final List<PackUsage> packs;

  /// Isi per paket bila baris ini bundling: stok dipotong dari produk-produk ini (qty × [qty]).
  final List<BundleItem> components;

  bool get isBundle => components.isNotEmpty;

  /// Diisi saat nota dibuat (harga khusus / promo).
  final int discountAmount;
  final String? discountId;
  final String discountLabel;

  int get looseQty => qty - packs.fold(0, (s, p) => s + p.qty);

  int get gross => packs.fold(0, (s, p) => s + p.total) + looseQty * unitPrice;

  /// Mis. "1 karton (isi 20) + 5 pcs".
  String get breakdownLabel => [
        for (final p in packs) '${p.count} ${p.name} (isi ${p.contents})',
        if (looseQty > 0 || packs.isEmpty) '$looseQty $unit',
      ].join(' + ');

  int get net => gross - discountAmount;

  CartLine copyWith({
    int? qty,
    int? unitPrice,
    PriceType? priceType,
    int? discountAmount,
    String? discountId,
    String? discountLabel,
    List<PackUsage>? packs,
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
        packs: packs ?? this.packs,
        components: components,
      );

  CartLine withoutDiscount() => CartLine(
        productId: productId,
        name: name,
        unit: unit,
        qty: qty,
        unitPrice: unitPrice,
        priceType: priceType,
        trackStock: trackStock,
        packs: packs,
        components: components,
      );

  @override
  List<Object?> get props => [productId, qty, unitPrice, priceType, discountAmount, discountId, packs, components];
}
