import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/widgets/app_layout.dart';

void main() {
  for (final width in [360.0, 680.0, 900.0]) {
    testWidgets('judul laporan tidak terjepit pada lebar $width', (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PageHeading(
                title: 'Laporan',
                subtitle: 'Ringkasan penjualan, laba, dan transaksi per periode.',
                actions: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 200,
                        child: FilledButton(onPressed: () {}, child: const Text('Data asli / Demo')),
                      ),
                      SizedBox(
                        width: 180,
                        child: FilledButton(onPressed: () {}, child: const Text('Harian / Bulanan')),
                      ),
                      SizedBox(
                        width: 220,
                        child: FilledButton(onPressed: () {}, child: const Text('Jumat, 30 Okt 2026')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Laporan'));
      final subtitle = tester.getRect(find.text('Ringkasan penjualan, laba, dan transaksi per periode.'));
      final filters = tester.getRect(find.text('Data asli / Demo'));
      expect(title.height, lessThan(60));
      expect(subtitle.height, lessThan(100));
      expect(filters.top, greaterThan(subtitle.bottom));
    });
  }
}
