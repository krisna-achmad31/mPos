import '../../products/domain/entities/product.dart';

/// Menu contoh POS kopi untuk data demo laporan. Tidak pernah ditulis ke menu asli; id berawalan `demo-menu-`.
abstract final class CafeDemoCatalog {
  // id, nama, kategori, harga jual, HPP per porsi
  static const _items = [
    ('demo-menu-espresso', 'Espresso', 'Kopi', 15000, 4200),
    ('demo-menu-americano', 'Americano', 'Kopi', 18000, 4600),
    ('demo-menu-kopsu-aren', 'Kopi Susu Gula Aren', 'Kopi', 20000, 6900),
    ('demo-menu-cafe-latte', 'Cafe Latte', 'Kopi', 25000, 7800),
    ('demo-menu-cappuccino', 'Cappuccino', 'Kopi', 25000, 7600),
    ('demo-menu-caramel-macchiato', 'Caramel Macchiato', 'Kopi', 30000, 9800),
    ('demo-menu-vanilla-latte', 'Vanilla Latte', 'Kopi', 28000, 9200),
    ('demo-menu-oat-latte', 'Oat Latte', 'Kopi', 32000, 11500),
    ('demo-menu-matcha-latte', 'Matcha Latte', 'Non Kopi', 28000, 9400),
    ('demo-menu-chocolate', 'Chocolate', 'Non Kopi', 25000, 7900),
    ('demo-menu-lychee-tea', 'Lychee Tea', 'Non Kopi', 22000, 6100),
    ('demo-menu-teh-tarik', 'Teh Tarik', 'Non Kopi', 18000, 4800),
    ('demo-menu-air-mineral', 'Air Mineral', 'Non Kopi', 6000, 2600),
    ('demo-menu-croissant', 'Croissant Butter', 'Makanan', 22000, 11000),
    ('demo-menu-roti-bakar', 'Roti Bakar Cokelat Keju', 'Makanan', 20000, 8500),
    ('demo-menu-kentang', 'Kentang Goreng', 'Makanan', 18000, 7200),
    ('demo-menu-nasi-goreng', 'Nasi Goreng Kampung', 'Makanan', 28000, 12500),
  ];

  static final List<Product> products = [
    for (final i in _items)
      Product(id: i.$1, name: i.$2, category: i.$3, unit: 'porsi', sellPrice: i.$4, trackStock: false),
  ];

  static final Map<String, int> hpp = {for (final i in _items) i.$1: i.$5};
}
