import 'package:intl/intl.dart';

import '../../sales/domain/entities/invoice.dart';
import '../../sales/domain/services/sale_calculator.dart';
import '../../settings/domain/store_settings.dart';

enum ReceiptAlign { left, center, right }

/// Satu baris struk thermal; lebarnya sudah pas jumlah karakter per baris.
class ReceiptLine {
  const ReceiptLine(this.text, {this.align = ReceiptAlign.left, this.bold = false, this.large = false});

  /// Garis pemisah selebar kertas.
  factory ReceiptLine.divider(int width) => ReceiptLine('-' * width);

  final String text;
  final ReceiptAlign align;
  final bool bold;

  /// Huruf dua kali lebih besar (nama toko, total).
  final bool large;

  @override
  String toString() => text;
}

/// Menyusun isi struk kasir sebagai teks monospace. Dipakai printer Bluetooth (ESC/POS)
/// dan PDF gulungan, jadi hasil cetak keduanya sama. Murni agar mudah dites.
abstract final class ReceiptLayout {
  static List<ReceiptLine> build({
    required Invoice invoice,
    required StoreSettings store,
    required int width,
    bool reprint = false,
  }) {
    final money = NumberFormat.decimalPattern('id_ID');
    String n(int v) => money.format(v);
    final lines = <ReceiptLine>[
      // Huruf besar memakai dua kolom per karakter.
      for (final w in wrap(store.storeName.trim().isEmpty ? 'POS Kopi' : store.storeName.trim(), width ~/ 2))
        ReceiptLine(w, align: ReceiptAlign.center, bold: true, large: true),
      for (final t in [store.address, store.phone].where((t) => t.trim().isNotEmpty))
        for (final w in wrap(t.trim(), width)) ReceiptLine(w, align: ReceiptAlign.center),
      if (reprint) const ReceiptLine('** CETAK ULANG **', align: ReceiptAlign.center, bold: true),
      ReceiptLine.divider(width),
      ReceiptLine(columns('No', invoice.number, width)),
      ReceiptLine(columns('Waktu', DateFormat('dd/MM/yyyy HH:mm').format(invoice.createdAt), width)),
      if (invoice.createdByName.isNotEmpty) ReceiptLine(columns('Kasir', invoice.createdByName, width)),
      if (invoice.customerName.isNotEmpty && invoice.customerName != 'UMUM')
        ReceiptLine(columns('Pelanggan', invoice.customerName, width)),
      ReceiptLine.divider(width),
    ];

    for (final l in invoice.lines) {
      for (final w in wrap(l.name, width)) {
        lines.add(ReceiptLine(w));
      }
      lines.add(ReceiptLine(columns('  ${l.qty} x ${n(l.unitPrice)}', n(l.gross), width)));
      if (l.discountAmount > 0) {
        lines.add(ReceiptLine(columns('  Diskon', '-${n(l.discountAmount)}', width)));
      }
    }

    final t = invoice.totals;
    lines
      ..add(ReceiptLine.divider(width))
      ..add(ReceiptLine(columns('Subtotal', n(t.subtotal), width)));
    if (t.totalDiscount > 0) lines.add(ReceiptLine(columns('Diskon', '-${n(t.totalDiscount)}', width)));
    if (t.tax > 0) lines.add(ReceiptLine(columns('Pajak ${_percent(t.taxPercent)}%', n(t.tax), width)));
    lines.add(ReceiptLine(columns('TOTAL', 'Rp ${n(t.total)}', width), bold: true));

    final method = invoice.paymentMethod;
    if (method != null) {
      lines.add(ReceiptLine(columns(method.label, n(method == PaymentMethod.cash ? invoice.paid + invoice.change : invoice.paid), width)));
      if (invoice.change > 0) lines.add(ReceiptLine(columns('Kembali', n(invoice.change), width)));
    }
    lines.add(ReceiptLine.divider(width));
    final footer = store.receiptFooter.trim().isEmpty ? 'Terima kasih' : store.receiptFooter.trim();
    for (final f in footer.split('\n')) {
      for (final w in wrap(f, width)) {
        lines.add(ReceiptLine(w, align: ReceiptAlign.center));
      }
    }
    return lines;
  }

  /// Kiri dan kanan dalam satu baris; kiri dipotong bila tidak muat.
  static String columns(String left, String right, int width) {
    final space = width - right.length - 1;
    if (space <= 0) return right.length > width ? right.substring(0, width) : right.padLeft(width);
    final l = left.length > space ? left.substring(0, space) : left;
    return '${l.padRight(space)} $right';
  }

  /// Memecah teks per kata agar tidak melebihi [width] karakter.
  static List<String> wrap(String text, int width) {
    final result = <String>[];
    var current = '';
    for (final word in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      var w = word;
      while (w.length > width) {
        if (current.isNotEmpty) {
          result.add(current);
          current = '';
        }
        result.add(w.substring(0, width));
        w = w.substring(width);
      }
      if (current.isEmpty) {
        current = w;
      } else if (current.length + 1 + w.length <= width) {
        current = '$current $w';
      } else {
        result.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) result.add(current);
    return result.isEmpty ? [''] : result;
  }

  static String _percent(double p) => p == p.roundToDouble() ? p.toInt().toString() : p.toString();
}
