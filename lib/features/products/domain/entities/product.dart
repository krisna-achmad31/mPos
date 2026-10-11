import 'package:equatable/equatable.dart';

/// Data produk yang boleh dilihat semua role (tanpa harga beli / HPP).
class Product extends Equatable {
  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.category = '',
    this.unit = 'pcs',
    required this.sellPrice,
    this.wholesalePrice = 0,
    this.wholesaleMinQty = 0,
    this.minStock = 0,
    this.trackStock = true,
    this.stock = 0,
    this.active = true,
  });

  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final String unit;
  final int sellPrice;

  /// Harga grosir berlaku otomatis bila qty >= [wholesaleMinQty].
  final int wholesalePrice;
  final int wholesaleMinQty;

  /// Batas order ulang: stok <= minStock memicu peringatan.
  final int minStock;

  /// false untuk jasa / barang tanpa stok: tidak pernah dicek stoknya.
  final bool trackStock;
  final int stock;
  final bool active;

  bool get hasWholesale => wholesalePrice > 0 && wholesaleMinQty > 0;

  bool get needsReorder => trackStock && stock <= minStock;

  bool get isOutOfStock => trackStock && stock <= 0;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || sku.toLowerCase().contains(q) || barcode == q;
  }

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    int? sellPrice,
    int? wholesalePrice,
    int? wholesaleMinQty,
    int? minStock,
    bool? trackStock,
    int? stock,
    bool? active,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        sellPrice: sellPrice ?? this.sellPrice,
        wholesalePrice: wholesalePrice ?? this.wholesalePrice,
        wholesaleMinQty: wholesaleMinQty ?? this.wholesaleMinQty,
        minStock: minStock ?? this.minStock,
        trackStock: trackStock ?? this.trackStock,
        stock: stock ?? this.stock,
        active: active ?? this.active,
      );

  @override
  List<Object?> get props => [
        id, name, sku, barcode, category, unit, sellPrice, wholesalePrice, wholesaleMinQty,
        minStock, trackStock, stock, active,
      ];
}

/// Harga beli dan HPP, disimpan terpisah karena hanya untuk Owner (dan SPV saat stok masuk).
class ProductCost extends Equatable {
  const ProductCost({required this.productId, this.buyPrice = 0, this.hpp = 0});

  final String productId;
  final int buyPrice;

  /// Harga pokok rata-rata tertimbang.
  final int hpp;

  @override
  List<Object?> get props => [productId, buyPrice, hpp];
}
