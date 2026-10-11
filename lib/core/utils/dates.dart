import 'package:intl/intl.dart';

String formatDate(DateTime date) => DateFormat('d MMM yyyy', 'id_ID').format(date);

String formatDateTime(DateTime date) => DateFormat('d MMM yyyy HH:mm', 'id_ID').format(date);

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);

DateTime startOfNextMonth(DateTime d) => DateTime(d.year, d.month + 1);
