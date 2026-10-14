import '../../products/domain/entities/product.dart';

/// Katalog contoh: distributor bahan & perlengkapan cafe, dengan 8 kategori bawaan dan harga per kemasan.
/// Tidak pernah ditulis ke koleksi produk asli; id selalu berawalan `demo-`.
abstract final class DemoCatalog {
  // id, nama, kategori, satuan dasar, harga satuan, HPP, harga grosir, min grosir, kemasan (nama, isi, harga)
  static const _items = [
    ('demo-arabika-gayo', 'Biji Kopi Arabika Gayo 1kg', 'Teh, Kopi & Kreamer', 'pack', 185000, 148000, 0, 0,
        [('karton', 10, 1760000)]),
    ('demo-robusta-lampung', 'Biji Kopi Robusta Lampung 1kg', 'Teh, Kopi & Kreamer', 'pack', 120000, 94000, 0, 0,
        [('karton', 10, 1140000)]),
    ('demo-espresso-blend', 'Espresso House Blend 1kg', 'Teh, Kopi & Kreamer', 'pack', 165000, 129000, 0, 0,
        [('karton', 10, 1570000)]),
    ('demo-decaf', 'Biji Kopi Decaf 500g', 'Teh, Kopi & Kreamer', 'pack', 110000, 86000, 0, 0, <(String, int, int)>[]),
    ('demo-teh-hitam', 'Teh Hitam Celup isi 100', 'Teh, Kopi & Kreamer', 'box', 46000, 36000, 0, 0,
        [('karton', 24, 1050000)]),
    ('demo-krimer', 'Krimer Bubuk 1kg', 'Teh, Kopi & Kreamer', 'pack', 62000, 49000, 0, 0, [('karton', 12, 700000)]),
    ('demo-uht-fullcream', 'Susu UHT Full Cream 1L', 'Dairy Product', 'kotak', 19500, 16200, 0, 0,
        [('karton', 12, 222000)]),
    ('demo-oat-barista', 'Susu Oat Barista 1L', 'Dairy Product', 'kotak', 42000, 34500, 0, 0, [('karton', 12, 480000)]),
    ('demo-skm', 'Susu Kental Manis 490g', 'Dairy Product', 'kaleng', 14500, 11800, 0, 0, [('karton', 48, 660000)]),
    ('demo-whip-cream', 'Whipping Cream 1L', 'Dairy Product', 'kotak', 78000, 63000, 0, 0, [('karton', 12, 900000)]),
    ('demo-sirup-vanilla', 'Sirup Vanilla 750ml', 'Sirup & Buah Kaleng', 'botol', 98000, 77000, 0, 0,
        [('karton', 12, 1110000)]),
    ('demo-sirup-hazelnut', 'Sirup Hazelnut 750ml', 'Sirup & Buah Kaleng', 'botol', 98000, 77000, 0, 0,
        [('karton', 12, 1110000)]),
    ('demo-sirup-caramel', 'Sirup Caramel 750ml', 'Sirup & Buah Kaleng', 'botol', 98000, 77000, 0, 0,
        [('karton', 12, 1110000)]),
    ('demo-gula-aren', 'Gula Aren Cair 1L', 'Sirup & Buah Kaleng', 'botol', 38000, 29500, 0, 0, [('karton', 12, 432000)]),
    ('demo-leci-kaleng', 'Leci Kaleng 565g', 'Sirup & Buah Kaleng', 'kaleng', 32000, 25000, 0, 0,
        [('karton', 24, 720000)]),
    ('demo-matcha', 'Bubuk Matcha Premium 500g', 'Powder', 'pack', 168000, 132000, 0, 0, [('karton', 20, 3200000)]),
    ('demo-cokelat', 'Bubuk Cokelat 1kg', 'Powder', 'pack', 96000, 75000, 0, 0, [('karton', 12, 1100000)]),
    ('demo-gula-sachet', 'Gula Pasir Sachet isi 100', 'Sembako', 'pack', 22000, 16800, 0, 0, [('bal', 10, 210000)]),
    ('demo-beras', 'Beras Premium 5kg', 'Sembako', 'karung', 78000, 66000, 76000, 5, <(String, int, int)>[]),
    ('demo-saus-sambal', 'Saus Sambal Sachet 9g', 'Saus & Bumbu', 'sachet', 600, 420, 0, 0,
        [('pouch', 24, 13500), ('karton', 576, 315000)]),
    ('demo-saus-tomat', 'Saus Tomat 1kg', 'Saus & Bumbu', 'botol', 28000, 21000, 0, 0, [('karton', 12, 320000)]),
    ('demo-kecap', 'Kecap Manis 5L', 'Saus & Bumbu', 'jerigen', 135000, 108000, 0, 0, <(String, int, int)>[]),
    ('demo-air-mineral', 'Air Mineral 600ml', 'Minuman', 'botol', 3500, 2500, 0, 0, [('karton', 24, 78000)]),
    ('demo-soda', 'Soda Water 330ml', 'Minuman', 'kaleng', 9000, 6800, 0, 0, [('karton', 24, 204000)]),
    ('demo-cup-16oz', 'Cup Plastik 16oz isi 50', 'Perlengkapan', 'pack', 32000, 24500, 0, 0, [('bal', 20, 600000)]),
    ('demo-paper-cup', 'Paper Cup Hot 8oz isi 50', 'Perlengkapan', 'pack', 36000, 27500, 0, 0, [('bal', 20, 680000)]),
    ('demo-sedotan', 'Sedotan Kertas isi 100', 'Perlengkapan', 'pack', 28000, 20500, 0, 0, [('bal', 25, 650000)]),
    ('demo-sealer', 'Roll Sealer Cup', 'Perlengkapan', 'roll', 145000, 117000, 0, 0, [('karton', 6, 840000)]),
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
        packs: [for (final p in i.$9) ProductPack(name: p.$1, contents: p.$2, price: p.$3)],
      ),
  ];

  static final Map<String, int> hpp = {for (final i in _items) i.$1: i.$6};

  /// Versi untuk dimasukkan ke produk asli: stok dihitung, dengan stok minimum & stok awal.
  static List<({Product product, int buyPrice, int initialStock})> get seedProducts => [
        for (final p in products)
          (
            product: p.copyWith(
              trackStock: true,
              // Stok minimum = 1 kemasan terbesar bila ada, supaya restock per karton/bal.
              minStock: p.packsBySize.isNotEmpty ? p.packsBySize.first.contents : (p.sellPrice >= 100000 ? 3 : 10),
            ),
            buyPrice: hpp[p.id]!,
            initialStock: p.packsBySize.isNotEmpty ? p.packsBySize.first.contents * 3 : (p.sellPrice >= 100000 ? 12 : 48),
          ),
      ];

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
