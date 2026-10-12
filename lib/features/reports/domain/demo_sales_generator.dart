import 'dart:math';

import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../pricing/domain/services/pricing_service.dart';
import '../../products/domain/entities/product.dart';
import '../../sales/domain/entities/cart_line.dart';
import '../../sales/domain/entities/invoice.dart';
import '../../sales/domain/services/sale_calculator.dart';

/// Pola belanja pembeli pada data demo.
enum BuyerProfile {
  /// Toko eceran: keranjang kecil, banyak pembeli umum.
  retail,

  /// Distributor (mis. ke cafe): lebih sedikit nota, banyak item & qty, hampir selalu pelanggan tetap.
  wholesale,

  /// POS kopi: keranjang kecil (1–2 cup), pelanggan umum, bayar tunai / QRIS, ramai pagi & sore.
  cafe,
}

/// Membuat transaksi contoh untuk MODE DEMO laporan.
///
/// Hasilnya tidak pernah disimpan sebagai nota asli: nomor berawalan `DEMO-`,
/// tidak mengubah stok, dan hanya tampil di laporan bertanda demo.
/// Total semua nota selalu <= [target].
class DemoSalesGenerator {
  DemoSalesGenerator({required int seed}) : _rnd = Random(seed);

  final Random _rnd;

  /// false (default): data demo tidak dibatasi stok asli, karena tidak pernah mengurangi stok.
  bool _respectStock = false;
  BuyerProfile _profile = BuyerProfile.retail;

  bool get _wholesale => _profile == BuyerProfile.wholesale;

  bool get _cafe => _profile == BuyerProfile.cafe;

  List<Invoice> generate({
    required DateTime date,
    required int target,
    required List<Product> products,
    List<String> customerNames = const [],
    int openHour = 8,
    int closeHour = 21,
    bool respectStock = false,
    BuyerProfile profile = BuyerProfile.retail,
  }) {
    _respectStock = respectStock;
    _profile = profile;
    if (target <= 0) throw const AppException('Target total harus lebih dari 0.');
    if (closeHour <= openHour) throw const AppException('Jam tutup harus setelah jam buka.');

    final eligible = products
        .where((p) => p.active && p.sellPrice > 0 && (!_respectStock || !p.trackStock || p.stock > 0))
        .toList();
    if (eligible.isEmpty) throw const AppException('Belum ada produk aktif yang bisa dipakai untuk data demo.');

    final popularity = _popularity(eligible);
    final usedQty = <String, int>{};
    final drafts = <({DateTime at, List<CartLine> lines, PaymentMethod method, String customer})>[];
    var remaining = target;

    for (var attempt = 0; attempt < 400; attempt++) {
      final cheapest = eligible
          .where((p) => _available(p, usedQty) > 0)
          .map((p) => p.sellPrice)
          .fold<int?>(null, (m, v) => m == null || v < m ? v : m);
      if (cheapest == null || remaining < cheapest) break;

      final lines = _basket(eligible, popularity, usedQty, remaining);
      if (lines.isEmpty) continue;

      final total = SaleCalculator.totals(lines).total;
      remaining -= total;
      for (final l in lines) {
        usedQty[l.productId] = (usedQty[l.productId] ?? 0) + l.qty;
      }
      drafts.add((
        at: _time(date, openHour, closeHour),
        lines: lines,
        method: _method(),
        customer: !_cafe && customerNames.isNotEmpty && _rnd.nextDouble() < (_wholesale ? 0.9 : 0.25)
            ? customerNames[_rnd.nextInt(customerNames.length)]
            : 'UMUM',
      ));
    }

    drafts.sort((a, b) => a.at.compareTo(b.at));
    final day = DateFormat('yyyyMMdd').format(date);
    return [for (var i = 0; i < drafts.length; i++) _invoice(drafts[i], day, i + 1)];
  }

  // Produk tertentu lebih laku dari yang lain; barang murah lebih sering dibeli.
  Map<String, double> _popularity(List<Product> products) {
    final prices = products.map((p) => p.sellPrice).toList()..sort();
    final median = prices[prices.length ~/ 2].toDouble();
    return {
      for (final p in products) p.id: (0.4 + _rnd.nextDouble() * 2.2) * sqrt(median / p.sellPrice).clamp(0.3, 2.5),
    };
  }

  int _available(Product p, Map<String, int> used) =>
      _respectStock && p.trackStock ? p.stock - (used[p.id] ?? 0) : 1 << 20;

  List<CartLine> _basket(List<Product> products, Map<String, double> popularity, Map<String, int> used, int budget) {
    final lineCount = _wholesale
        ? _weighted({2: 20, 3: 30, 4: 25, 5: 15, 6: 10})
        : _cafe
            ? _weighted({1: 50, 2: 32, 3: 13, 4: 5})
            : _weighted({1: 45, 2: 30, 3: 15, 4: 7, 5: 3});
    final lines = <CartLine>[];
    var spent = 0;

    for (var n = 0; n < lineCount; n++) {
      final inBasket = lines.map((l) => l.productId).toSet();
      final candidates = products
          .where((p) => !inBasket.contains(p.id) && _available(p, used) > 0 && p.sellPrice <= budget - spent)
          .toList();
      if (candidates.isEmpty) break;

      final product = _pick(candidates, popularity);
      var qty = _quantity(product);
      qty = min(qty, _available(product, used));
      // Turunkan qty sampai muat di sisa target.
      while (qty > 0 && _lineTotal(product, qty) > budget - spent) {
        qty--;
      }
      if (qty <= 0) continue;

      final price = PricingService.priceLine(product, qty);
      final line = CartLine(
        productId: product.id,
        name: product.name,
        unit: product.unit,
        qty: qty,
        unitPrice: price.unitPrice,
        priceType: price.type,
        trackStock: product.trackStock,
        packs: price.packs,
      );
      lines.add(line);
      spent += line.gross;
    }
    return lines;
  }

  int _lineTotal(Product p, int qty) {
    final price = PricingService.priceLine(p, qty);
    final packed = price.packs.fold(0, (s, x) => s + x.qty);
    return price.packs.fold(0, (s, x) => s + x.total) + (qty - packed) * price.unitPrice;
  }

  // Kebanyakan pembeli membeli 1–3; sesekali borongan (harga grosir bila ada).
  int _quantity(Product p) {
    final r = _rnd.nextDouble();
    if (_cafe) {
      if (r < 0.75) return 1;
      if (r < 0.95) return 2;
      return 3 + _rnd.nextInt(3);
    }
    if (_wholesale) {
      if (r < 0.35) return 1 + _rnd.nextInt(3);
      if (r < 0.75) return 4 + _rnd.nextInt(5);
      if (p.hasWholesale) return p.wholesaleMinQty + _rnd.nextInt(max(1, p.wholesaleMinQty));
      return 10 + _rnd.nextInt(11);
    }
    if (r < 0.55) return 1;
    if (r < 0.82) return 2 + _rnd.nextInt(2);
    if (r < 0.95) return 4 + _rnd.nextInt(3);
    if (p.hasWholesale) return p.wholesaleMinQty + _rnd.nextInt(max(1, p.wholesaleMinQty ~/ 2));
    return 6 + _rnd.nextInt(7);
  }

  Product _pick(List<Product> candidates, Map<String, double> popularity) {
    final total = candidates.fold(0.0, (s, p) => s + popularity[p.id]!);
    var r = _rnd.nextDouble() * total;
    for (final p in candidates) {
      r -= popularity[p.id]!;
      if (r <= 0) return p;
    }
    return candidates.last;
  }

  // Ramai pagi (09–11) dan sore (16–19), sedang saat makan siang, sepi menjelang tutup.
  DateTime _time(DateTime date, int open, int close) {
    double weight(int h) {
      if (_cafe) {
        if (h >= 7 && h <= 9) return 2.4;
        if (h >= 15 && h <= 17) return 2.2;
        if (h >= 19 && h <= 21) return 1.8;
        if (h == 12 || h == 13) return 1.5;
        return 0.8;
      }
      if (h >= 9 && h <= 11) return 2.2;
      if (h >= 16 && h <= 19) return 2.0;
      if (h == 12 || h == 13) return 1.3;
      if (h >= 20) return 0.7;
      return 1.0;
    }

    final hours = [for (var h = open; h < close; h++) h];
    final total = hours.fold(0.0, (s, h) => s + weight(h));
    var r = _rnd.nextDouble() * total;
    var hour = hours.last;
    for (final h in hours) {
      r -= weight(h);
      if (r <= 0) {
        hour = h;
        break;
      }
    }
    return DateTime(date.year, date.month, date.day, hour, _rnd.nextInt(60), _rnd.nextInt(60));
  }

  PaymentMethod _method() {
    final r = _rnd.nextDouble();
    if (_cafe) {
      if (r < 0.45) return PaymentMethod.cash;
      if (r < 0.93) return PaymentMethod.qris;
      return PaymentMethod.transfer;
    }
    if (r < 0.62) return PaymentMethod.cash;
    if (r < 0.92) return PaymentMethod.transfer;
    return PaymentMethod.credit;
  }

  int _weighted(Map<int, int> weights) {
    final total = weights.values.fold(0, (s, w) => s + w);
    var r = _rnd.nextInt(total);
    for (final e in weights.entries) {
      r -= e.value;
      if (r < 0) return e.key;
    }
    return weights.keys.first;
  }

  // Uang tunai dibulatkan seperti pembeli sungguhan (pas, atau pecahan 5rb/10rb/50rb/100rb).
  int _cashGiven(int total) {
    final steps = [0, 5000, 10000, 50000, 100000];
    final step = steps[_rnd.nextInt(steps.length)];
    if (step == 0) return total;
    return ((total + step - 1) ~/ step) * step;
  }

  Invoice _invoice(
    ({DateTime at, List<CartLine> lines, PaymentMethod method, String customer}) d,
    String day,
    int seq,
  ) {
    final totals = SaleCalculator.totals(d.lines);
    final payment = SaleCalculator.pay(
      total: totals.total,
      method: d.method,
      amount: d.method == PaymentMethod.cash ? _cashGiven(totals.total) : 0,
    );
    return Invoice(
      id: 'demo-$day-$seq',
      number: 'DEMO-$day-${seq.toString().padLeft(4, '0')}',
      source: !_cafe && d.customer != 'UMUM' && _rnd.nextBool() ? InvoiceSource.online : InvoiceSource.pos,
      customerName: d.customer,
      lines: d.lines,
      totals: totals,
      paid: payment.paid,
      change: payment.change,
      paymentMethod: d.method,
      createdAt: d.at,
      createdByName: 'Demo',
    );
  }
}
