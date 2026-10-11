import 'package:cloud_firestore/cloud_firestore.dart';

int readInt(Object? value) => value is num ? value.toInt() : 0;

double readDouble(Object? value) => value is num ? value.toDouble() : 0;

String readString(Object? value) => value is String ? value : '';

String? readNullableString(Object? value) => value is String && value.isNotEmpty ? value : null;

bool readBool(Object? value, {bool fallback = false}) => value is bool ? value : fallback;

/// serverTimestamp() bernilai null sampai tulisan dikonfirmasi server.
DateTime readDate(Object? value) => value is Timestamp ? value.toDate() : DateTime.now();

DateTime? readNullableDate(Object? value) => value is Timestamp ? value.toDate() : null;

List<Map<String, dynamic>> readMapList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];
