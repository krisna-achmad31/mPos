import '../../products/domain/entities/product.dart';

/// Katalog contoh untuk MODE DEMO: distributor bahan & perlengkapan cafe.
/// Tidak pernah ditulis ke koleksi produk asli; id selalu berawalan `demo-`.
abstract final class DemoCatalog {
  static const _items = [
    // id, nama, kategori, satuan, harga jual, HPP, harga grosir, min grosir
    ('demo-arabika-gayo', 'Biji Kopi Arabika Gayo 1kg', 'Kopi', 'pack', 185000, 148000, 176000, 5),
    ('demo-robusta-lampung', 'Biji Kopi Robusta Lampung 1kg', 'Kopi', 'pack', 120000, 94000, 113000, 5),
    ('demo-espresso-blend', 'Espresso House Blend 1kg', 'Kopi', 'pack', 165000, 129000, 156000, 5),
    ('demo-decaf', 'Biji Kopi Decaf 500g', 'Kopi', 'pack', 110000, 86000, 0, 0),
    ('demo-uht-fullcream', 'Susu UHT Full Cream 1L', 'Susu & Krimer', 'kotak', 19500, 16200, 18300, 12),
    ('demo-oat-barista', 'Susu Oat Barista 1L', 'Susu & Krimer', 'kotak', 42000, 34500, 39500, 12),
    ('demo-skm', 'Susu Kental Manis 490g', 'Susu & Krimer', 'kaleng', 14500, 11800, 13600, 24),
    ('demo-whip-cream', 'Whipping Cream 1L', 'Susu & Krimer', 'kotak', 78000, 63000, 0, 0),
    ('demo-sirup-vanilla', 'Sirup Vanilla 750ml', 'Sirup', 'botol', 98000, 77000, 92000, 6),
    ('demo-sirup-hazelnut', 'Sirup Hazelnut 750ml', 'Sirup', 'botol', 98000, 77000, 92000, 6),
    ('demo-sirup-caramel', 'Sirup Caramel 750ml', 'Sirup', 'botol', 98000, 77000, 92000, 6),
    ('demo-gula-aren', 'Gula Aren Cair 1L', 'Pemanis', 'botol', 38000, 29500, 35000, 6),
    ('demo-gula-sachet', 'Gula Pasir Sachet isi 100', 'Pemanis', 'pack', 22000, 16800, 0, 0),
    ('demo-matcha', 'Bubuk Matcha Premium 500g', 'Bubuk Minuman', 'pack', 168000, 132000, 0, 0),
    ('demo-cokelat', 'Bubuk Cokelat 1kg', 'Bubuk Minuman', 'pack', 96000, 75000, 90000, 5),
    ('demo-teh-hitam', 'Teh Hitam Celup isi 100', 'Teh', 'box', 46000, 36000, 0, 0),
    ('demo-cup-16oz', 'Cup Plastik 16oz isi 50', 'Kemasan', 'pack', 32000, 24500, 29000, 10),
    ('demo-paper-cup', 'Paper Cup Hot 8oz isi 50', 'Kemasan', 'pack', 36000, 27500, 33000, 10),
    ('demo-sedotan', 'Sedotan Kertas isi 100', 'Kemasan', 'pack', 28000, 20500, 0, 0),
    ('demo-sealer', 'Roll Sealer Cup', 'Kemasan', 'roll', 145000, 117000, 0, 0),
  ];

  static final List<Product> products = [
    for (final i in _items)
      Product(
        id: i.$1,
        name: i.$2,
        category: i.$3,
        unit: i.$4,
        sellPrice: i.$5,
        wholesalePrice: i.$7,
        wholesaleMinQty: i.$8,
        trackStock: false,
      ),
  ];

  static final Map<String, int> hpp = {for (final i in _items) i.$1: i.$6};

  /// Pelanggan contoh (nama fiktif).
  static const customers = [
    'Kopi Senja Sore',
    'Ruang Temu Coffee',
    'Kedai Teduh',
    'Sudut Seduh',
    'Langit Kopi',
    'Kafe Arunika',
    'Warung Kopi Pak Darmo',
    'Seduh Pagi Roastery',
  ];
}
