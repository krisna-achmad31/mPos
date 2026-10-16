import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart' as layout;
import '../../domain/sales_report.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, this.subtitle, required this.child, this.trailing});

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      layout.SectionCard(title: title, subtitle: subtitle, trailing: trailing, child: child);
}

class KpiTile extends StatelessWidget {
  const KpiTile({super.key, required this.label, required this.value, this.hint, this.icon});

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => layout.KpiTile(label: label, value: value, hint: hint, icon: icon);
}

/// Grafik batang omzet per waktu (per hari dalam sebulan, atau per jam dalam sehari).
class TimeBarChart extends StatelessWidget {
  const TimeBarChart({super.key, required this.buckets, required this.label});

  final List<TimeBucket> buckets;

  /// Teks sumbu bawah untuk tiap batang.
  final String Function(TimeBucket bucket) label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = buckets.fold(0, (m, b) => b.amount > m ? b.amount : m);
    if (maxY == 0) {
      return const SizedBox(height: 120, child: Center(child: Text('Belum ada penjualan di periode ini')));
    }
    final every = buckets.length > 16 ? (buckets.length / 8).ceil() : 1;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.15,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) => value == meta.max
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(formatCompact(value), style: Theme.of(context).textTheme.labelSmall),
                      ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i % every != 0 || i >= buckets.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(label(buckets[i]), style: Theme.of(context).textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, _, rod, _) {
                final b = buckets[group.x];
                return BarTooltipItem(
                  '${label(b)}\n${formatRupiah(b.amount)}\n${b.count} nota',
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i].amount.toDouble(),
                    color: scheme.primary,
                    width: buckets.length > 20 ? 7 : 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Daftar dengan batang proporsi: nama, batang, nilai.
class ProportionList extends StatelessWidget {
  const ProportionList({super.key, required this.items, this.showCount = true, this.limit});

  final List<NamedAmount> items;
  final bool showCount;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('Belum ada data');
    final shown = limit == null ? items : items.take(limit!).toList();
    final total = items.fold(0, (s, i) => s + i.amount);
    final max = shown.first.amount == 0 ? 1 : shown.first.amount;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      spacing: 10,
      children: [
        for (final item in shown)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: [
              Row(
                children: [
                  Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(formatRupiah(item.amount), style: text.titleSmall),
                ],
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.amount / max,
                        minHeight: 8,
                        color: scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${total == 0 ? 0 : (item.amount * 100 / total).toStringAsFixed(1)}%'
                      '${showCount ? ' · ${item.count}x' : ''}',
                      textAlign: TextAlign.end,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// Donat proporsi (dipakai untuk metode bayar dan sumber penjualan).
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.items});

  final List<NamedAmount> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [scheme.primary, scheme.tertiary, scheme.secondary, scheme.error, scheme.outline];
    final total = items.fold(0, (s, i) => s + i.amount);
    if (total == 0) return const Text('Belum ada data');

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 36,
              sectionsSpace: 2,
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: items[i].amount.toDouble(),
                    color: colors[i % colors.length],
                    radius: 30,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              for (var i = 0; i < items.length; i++)
                Row(
                  spacing: 8,
                  children: [
                    Container(width: 10, height: 10, color: colors[i % colors.length]),
                    Expanded(child: Text(items[i].name)),
                    Text('${(items[i].amount * 100 / total).toStringAsFixed(0)}% · ${formatRupiah(items[i].amount)}'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String dayLabel(TimeBucket b) => '${b.start.day}';

String hourLabel(TimeBucket b) => b.start.hour.toString().padLeft(2, '0');

String timeOf(DateTime d) => DateFormat('HH:mm').format(d);
