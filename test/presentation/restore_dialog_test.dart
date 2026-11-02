import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mpos/features/backup/domain/backup_groups.dart';
import 'package:mpos/features/backup/presentation/views/restore_dialog.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<void> open(WidgetTester tester, void Function(Set<BackupGroup>?) onResult) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                onResult(await RestoreDialog.show(context, (createdAt: DateTime(2026, 11, 2), documentCount: 10))),
            child: const Text('buka'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('ganti semua harus dicentang "Saya mengerti" dulu', (tester) async {
    await open(tester, (_) {});
    final confirm = find.widgetWithText(FilledButton, 'Ganti semua data');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('Saya mengerti dan ingin melanjutkan'));
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
  });

  testWidgets('sebagian: hanya grup yang dicentang yang dikembalikan', (tester) async {
    Set<BackupGroup>? result;
    await open(tester, (r) => result = r);
    await tester.tap(find.text('Sebagian saja'));
    await tester.pump();
    await tester.tap(find.text(BackupGroup.stock.label));
    await tester.tap(find.text('Saya mengerti dan ingin melanjutkan'));
    await tester.pump();
    await tester.tap(find.text('Load bagian terpilih'));
    await tester.pumpAndSettle();
    expect(result, {BackupGroup.stock});
  });
}
