import '../../../core/error/app_exception.dart';
import '../../sales/domain/entities/cart_line.dart';
import 'cafe.dart';

/// Aturan POS kopi yang murni (tanpa Firebase) agar mudah dites.
abstract final class CafeRules {
  /// Total pemakaian bahan untuk keranjang: qty menu × resep. Menu tanpa resep tidak memakai bahan.
  static Map<String, double> usage(List<CartLine> lines, Map<String, Recipe> recipes) {
    final result = <String, double>{};
    for (final line in lines) {
      for (final r in recipes[line.productId]?.lines ?? const <RecipeLine>[]) {
        result[r.ingredientId] = (result[r.ingredientId] ?? 0) + r.qty * line.qty;
      }
    }
    return result;
  }

  /// Bahan yang stoknya tidak cukup, mis. "Susu UHT (butuh 400 ml, sisa 250 ml)".
  static List<String> shortages(Map<String, double> usage, Map<String, Ingredient> ingredients) => [
        for (final e in usage.entries)
          if (ingredients[e.key] case final i? when e.value > i.stock + 1e-9)
            '${i.name} (butuh ${formatQty(e.value)} ${i.unit}, sisa ${formatQty(i.stock)} ${i.unit})'
          else if (ingredients[e.key] == null)
            'Bahan resep sudah dihapus (${e.key})',
      ];

  /// HPP pemakaian bahan, dibulatkan ke rupiah.
  static int cost(Map<String, double> usage, Map<String, Ingredient> ingredients) =>
      usage.entries.fold(0.0, (s, e) => s + e.value * (ingredients[e.key]?.avgCost ?? 0)).round();

  /// HPP satu porsi menu dari resepnya.
  static int menuCost(Recipe? recipe, Map<String, Ingredient> ingredients) =>
      recipe == null ? 0 : cost({for (final l in recipe.lines) l.ingredientId: l.qty}, ingredients);

  /// Bahan setelah menerima [line] dari distributor: stok bertambah qty × isi per kemasan,
  /// HPP rata-rata tertimbang memakai harga bersih baris nota.
  /// [existing] null = bahan baru, satuannya mengikuti satuan produk distributor.
  static Ingredient receive(Ingredient? existing, CartLine line) {
    final base = existing ??
        Ingredient(
          id: Ingredient.idForProduct(line.productId),
          name: line.name,
          unit: line.unit,
          purchaseUnit: line.unit,
          sourceProductId: line.productId,
        );
    final added = line.qty * base.perPurchase;
    if (added <= 0) return base;
    final unitCost = line.net / added;
    final oldStock = base.stock > 0 ? base.stock : 0.0;
    final avgCost = oldStock + added == 0 ? unitCost : (oldStock * base.avgCost + added * unitCost) / (oldStock + added);
    return base.copyWith(stock: base.stock + added, avgCost: avgCost);
  }

  /// Ganti konversi kemasan: stok & HPP ikut diskalakan agar jumlah fisiknya tetap.
  static Ingredient changeConversion(Ingredient i, {required String unit, required double perPurchase}) {
    if (perPurchase <= 0) throw const AppException('Isi per kemasan harus lebih dari 0.');
    final factor = perPurchase / i.perPurchase;
    return i.copyWith(unit: unit, perPurchase: perPurchase, stock: i.stock * factor, avgCost: i.avgCost / factor);
  }

  /// Masa premium setelah kode dipakai: diperpanjang dari tanggal berakhir bila masih aktif.
  static DateTime extendPremium(DateTime? current, DateTime now, int days) {
    final start = current != null && current.isAfter(now) ? current : now;
    return DateTime(start.year, start.month, start.day + days, start.hour, start.minute);
  }

  /// Kode promo disimpan huruf besar tanpa spasi.
  static String normalizeCode(String code) => code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Nomor struk K-YYYYMMDD-#### (urut per hari).
  static String receiptNumber(String dayKey, int seq) => 'K-$dayKey-${seq.toString().padLeft(4, '0')}';
}
