import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mpos/features/reports/presentation/viewmodels/report_view_model.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('tanggal: dari-sampai inklusif, urutan terbalik dirapikan', () {
    final r = ExportRange.days(DateTime(2026, 10, 15, 14), DateTime(2026, 10, 1));
    expect(r.from, DateTime(2026, 10, 1));
    expect(r.to, DateTime(2026, 10, 16));
    expect(r.label, '1 Okt 2026 - 15 Okt 2026');
    expect(ExportRange.days(DateTime(2026, 10, 12), DateTime(2026, 10, 12)).label, '12 Okt 2026');
  });

  test('bulan dan tahun', () {
    final m = ExportRange.month(2026, 12);
    expect(m.from, DateTime(2026, 12));
    expect(m.to, DateTime(2027, 1));
    expect(m.label, 'Desember 2026');
    final y = ExportRange.year(2026);
    expect(y.to, DateTime(2027));
    expect(ReportExportViewModel.fileName(y, ReportMode.real), 'Rekap Penjualan 2026.xlsx');
    expect(ReportExportViewModel.fileName(m, ReportMode.demo), 'Rekap Penjualan (Demo) Desember 2026.xlsx');
  });
}
