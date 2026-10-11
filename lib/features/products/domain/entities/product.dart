import 'package:equatable/equatable.dart';

/// Kemasan jual selain satuan dasar, mis. karton isi 20 / ball isi 10 / pouch isi 6.
class ProductPack extends Equatable {
  const ProductPack({required this.name, required this.contents, required this.price});

  static const presetNames = ['karton', 'ball', 'pouch'];

  final String name;

  /// Isi dalam satuan dasar produk (mis. 20 pcs per karton).
  final int contents;

  /// Harga satu kemasan.
  final int price;

  bool get isValid => name.trim().isNotEmpty && contents > 1 && price > 0;

  @override
  List<Object?> get props => [name, contents, price];
}

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
    this.packs = const [],
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

  /// Harga per kemasan (karton/ball/pouch). Pembelian otomatis dipecah ke kemasan terbesar dulu.
  final List<ProductPack> packs;

  /// Kemasan valid, isi terbesar dulu.
  List<ProductPack> get packsBySize => packs.where((p) => p.isValid).toList()..sort((a, b) => b.contents.compareTo(a.contents));

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
    List<ProductPack>? packs,
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
        packs: packs ?? this.packs,
      );

  @override
  List<Object?> get props => [
        id, name, sku, barcode, category, unit, sellPrice, wholesalePrice, wholesaleMinQty,
        minStock, trackStock, stock, active, packs,
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
