/// Kategori produk dipilih dari daftar (bukan diketik bebas) agar laporan per kategori rapi.
abstract final class ProductCategories {
  static const defaults = [
    'Saus & Bumbu',
    'Powder',
    'Perlengkapan',
    'Minuman',
    'Dairy Product',
    'Sembako',
    'Sirup & Buah Kaleng',
    'Teh, Kopi & Kreamer',
  ];

  /// Gabungan bawaan + tambahan Owner, tanpa duplikat (tidak peka huruf besar/kecil).
  static List<String> merge(Iterable<String> custom) {
    final result = [...defaults];
    for (final c in custom) {
      final name = c.trim();
      if (name.isNotEmpty && !result.any((r) => r.toLowerCase() == name.toLowerCase())) result.add(name);
    }
    return result;
  }
}
