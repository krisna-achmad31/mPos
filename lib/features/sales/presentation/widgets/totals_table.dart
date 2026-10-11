import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../domain/services/sale_calculator.dart';

class TotalsTable extends StatelessWidget {
  const TotalsTable({super.key, required this.totals, this.showItemDiscount = true});

  final SaleTotals totals;
  final bool showItemDiscount;

  @override
  Widget build(BuildContext context) {
    final bold = Theme.of(context).textTheme.titleMedium;
    Widget row(String label, int value, {TextStyle? style, bool negative = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: style)),
              Text('${negative ? '−' : ''}${formatRupiah(value)}', style: style),
            ],
          ),
        );
    return Column(
      children: [
        row('Subtotal', totals.subtotal),
        if (showItemDiscount && totals.itemDiscount > 0) row('Diskon pelanggan / promo', totals.itemDiscount, negative: true),
        if (totals.orderDiscount > 0) row('Diskon nota', totals.orderDiscount, negative: true),
        if (totals.tax > 0) row('Pajak ${totals.taxPercent.toStringAsFixed(totals.taxPercent % 1 == 0 ? 0 : 1)}%', totals.tax),
        const Divider(),
        row('Total', totals.total, style: bold),
      ],
    );
  }
}
