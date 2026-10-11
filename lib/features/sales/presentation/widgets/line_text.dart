import '../../../../core/utils/money.dart';
import '../../domain/entities/cart_line.dart';

/// Rincian harga satu baris, mis. "1 karton × Rp1.800.000 + 5 botol × Rp100.000".
String lineDetail(CartLine l) {
  if (l.packs.isEmpty) return '${l.qty} ${l.unit} × ${formatRupiah(l.unitPrice)}';
  return [
    for (final p in l.packs) '${p.count} ${p.name} (isi ${p.contents}) × ${formatRupiah(p.price)}',
    if (l.looseQty > 0) '${l.looseQty} ${l.unit} × ${formatRupiah(l.unitPrice)}',
  ].join(' + ');
}
