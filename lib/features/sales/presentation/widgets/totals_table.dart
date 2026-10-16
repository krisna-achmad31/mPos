import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../domain/services/sale_calculator.dart';

/// Ringkasan rincian nota (padanan panel `Order totals` / `Total` di desain).
///
/// Baris memakai [InfoRow] agar sejajar dengan panel rincian lain.
class TotalsTable extends StatelessWidget {
  const TotalsTable({super.key, required this.totals, this.showItemDiscount = true});

  final SaleTotals totals;
  final bool showItemDiscount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        InfoRow(label: 'Subtotal', value: formatRupiah(totals.subtotal)),
        if (showItemDiscount && totals.itemDiscount > 0)
          InfoRow(
            label: 'Diskon pelanggan / promo',
            value: '−${formatRupiah(totals.itemDiscount)}',
            valueColor: tokens.success,
          ),
        if (totals.orderDiscount > 0)
          InfoRow(
            label: 'Diskon nota',
            value: '−${formatRupiah(totals.orderDiscount)}',
            valueColor: tokens.success,
          ),
        if (totals.tax > 0)
          InfoRow(
            label: 'Pajak ${totals.taxPercent.toStringAsFixed(totals.taxPercent % 1 == 0 ? 0 : 1)}%',
            value: formatRupiah(totals.tax),
          ),
        const Divider(height: AppSpacing.xxl),
        InfoRow(label: 'Total', value: formatRupiah(totals.total), bold: true),
      ],
    );
  }
}
