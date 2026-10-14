import '../../../../core/utils/money.dart';
import '../../../products/domain/services/bundle_rules.dart';
import '../../domain/entities/cart_line.dart';

/// Rincian harga satu baris, mis. "1 karton × Rp1.800.000 + 5 botol × Rp100.000".
String lineDetail(CartLine l) {
  if (l.isBundle) {
    return '${l.qty} ${l.unit} × ${formatRupiah(l.unitPrice)} · isi: ${BundleRules.contentsLabel(l.components)}';
  }
  if (l.packs.isEmpty) return '${l.qty} ${l.unit} × ${formatRupiah(l.unitPrice)}';
  return [
    for (final p in l.packs) '${p.count} ${p.name} (isi ${p.contents}) × ${formatRupiah(p.price)}',
    if (l.looseQty > 0) '${l.looseQty} ${l.unit} × ${formatRupiah(l.unitPrice)}',
  ].join(' + ');
}
