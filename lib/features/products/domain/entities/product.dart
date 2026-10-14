import 'package:equatable/equatable.dart';

/// Kemasan jual selain satuan dasar, mis. karton isi 20 / bal isi 10 / sak isi 25 (kg).
class ProductPack extends Equatable {
  const ProductPack({required this.name, required this.contents, required this.price});

  /// Pouch dipertahankan untuk produk lama.
  static const presetNames = ['karton', 'bal', 'sak', 'pouch'];

  /// Nama kemasan baku; "ball" (data lama) = "bal".
  static String canonicalName(String name) {
    final n = name.trim().toLowerCase();
    return n == 'ball' ? 'bal' : n;
  }

  final String name;

  /// Isi dalam satuan dasar produk (mis. 20 pcs per karton).
  final int contents;

  /// Harga satu kemasan.
  final int price;

  bool get isValid => name.trim().isNotEmpty && contents > 1 && price > 0;

  /// Mis. "1 karton = 24 botol".
  String label(String unit) => '1 ${canonicalName(name)} = $contents $unit';

  @override
  List<Object?> get props => [name, contents, price];
}

/// Satu isi paket bundling: produk biasa + qty per paket.
/// Nama, satuan, dan harga normal disalin saat bundling disimpan.
class BundleItem extends Equatable {
  const BundleItem({
    required this.productId,
    required this.name,
    required this.qty,
    this.unit = 'pcs',
    this.price = 0,
    int? bundlePrice,
    this.trackStock = true,
  }) : bundlePrice = bundlePrice ?? price;

  final String productId;
  final String name;

  /// Jumlah satuan dasar produk ini dalam satu paket.
  final int qty;
  final String unit;

  /// Harga jual satuan normal saat bundling disimpan (untuk "hemat" & pembagian nilai).
  final int price;

  /// Harga per satuan di dalam paket (diinput Owner). Harga paket = jumlah [bundleTotal] semua isi.
  final int bundlePrice;
  final bool trackStock;

  int get normalTotal => price * qty;

  int get bundleTotal => bundlePrice * qty;

  BundleItem copyWith({int? qty, int? bundlePrice}) => BundleItem(
        productId: productId,
        name: name,
        qty: qty ?? this.qty,
        unit: unit,
        price: price,
        bundlePrice: bundlePrice ?? this.bundlePrice,
        trackStock: trackStock,
      );

  @override
  List<Object?> get props => [productId, name, qty, unit, price, bundlePrice, trackStock];
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
    this.imageBase64 = '',
    this.bundleItems = const [],
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

  /// Harga per kemasan (karton/bal/sak/pouch). Pembelian otomatis dipecah ke kemasan terbesar dulu.
  final List<ProductPack> packs;

  /// Foto produk (JPEG, base64). Kosong untuk produk lama / tanpa foto: tampilan memakai gambar default.
  final String imageBase64;

  /// Isi paket bundling. Kosong untuk produk biasa.
  /// Bundling tidak punya stok sendiri: stoknya dihitung dari stok isinya (lihat BundleRules).
  final List<BundleItem> bundleItems;

  bool get isBundle => bundleItems.isNotEmpty;

  bool get hasImage => imageBase64.isNotEmpty;

  /// Satuan dasar yang umum; Owner tetap bisa mengetik sendiri.
  static const unitPresets = ['pcs', 'kg', 'botol', 'pack', 'liter', 'karung'];

  /// Isi tiap kemasan, mis. "1 karton = 24 pcs · 1 bal = 10 pcs". Kosong bila hanya dijual satuan.
  String get packsLabel => packsBySize.map((p) => p.label(unit)).join(' · ');

  /// Kemasan valid, isi terbesar dulu.
  List<ProductPack> get packsBySize => packs.where((p) => p.isValid).toList()..sort((a, b) => b.contents.compareTo(a.contents));

  bool get hasWholesale => wholesalePrice > 0 && wholesaleMinQty > 0;

  /// Bundling tidak di-restock sendiri; yang di-restock isinya.
  bool get needsReorder => trackStock && !isBundle && stock <= minStock;

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
    String? imageBase64,
    List<BundleItem>? bundleItems,
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
        imageBase64: imageBase64 ?? this.imageBase64,
        bundleItems: bundleItems ?? this.bundleItems,
      );

  @override
  List<Object?> get props => [
        id, name, sku, barcode, category, unit, sellPrice, wholesalePrice, wholesaleMinQty,
        minStock, trackStock, stock, active, packs, imageBase64, bundleItems,
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
