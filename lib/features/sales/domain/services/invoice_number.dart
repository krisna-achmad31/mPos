import 'package:intl/intl.dart';

/// Format nomor nota INV-YYYYMMDD-#### (urut per hari dari counter di database).
abstract final class InvoiceNumber {
  static String dayKey(DateTime date) => DateFormat('yyyyMMdd').format(date);

  static String format(DateTime date, int sequence) =>
      'INV-${dayKey(date)}-${sequence.toString().padLeft(4, '0')}';
}
