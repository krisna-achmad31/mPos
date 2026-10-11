import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
final _number = NumberFormat.decimalPattern('id_ID');

String formatRupiah(num value) => _rupiah.format(value);

String formatNumber(num value) => _number.format(value);

/// Mengubah input teks seperti "Rp 12.500" menjadi 12500.
int parseRupiah(String text) => int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
