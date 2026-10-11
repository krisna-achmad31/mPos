import 'package:equatable/equatable.dart';

enum DiscountKind {
  /// Harga khusus untuk customer tertentu, tidak terlihat di katalog.
  special('Harga khusus customer'),

  /// Promo per item / per akun / item + akun.
  promo('Promo');

  const DiscountKind(this.label);

  final String label;
}

enum DiscountType { percent, amount }

class Discount extends Equatable {
  const Discount({
    required this.id,
    required this.name,
    required this.kind,
    required this.type,
    required this.value,
    this.productId,
    this.productName = '',
    this.customerId,
    this.customerName = '',
    this.visibleInCatalog = false,
    this.start,
    this.end,
    this.active = true,
  });

  final String id;
  final String name;
  final DiscountKind kind;
  final DiscountType type;

  /// Persen (0–100) atau Rupiah per unit.
  final double value;

  /// null = semua produk.
  final String? productId;
  final String productName;

  /// null = semua customer.
  final String? customerId;
  final String customerName;

  /// true = tampil sebagai harga coret di katalog. Harga khusus selalu tersembunyi.
  final bool visibleInCatalog;
  final DateTime? start;
  final DateTime? end;
  final bool active;

  bool isValidAt(DateTime now) =>
      active && (start == null || !now.isBefore(start!)) && (end == null || now.isBefore(end!));

  bool appliesTo({required String productId, String? customerId}) =>
      (this.productId == null || this.productId == productId) &&
      (this.customerId == null || this.customerId == customerId);

  /// Potongan Rupiah untuk satu baris, tidak melebihi nilai baris.
  int amountFor({required int unitPrice, required int qty}) {
    final gross = unitPrice * qty;
    final raw = switch (type) {
      DiscountType.percent => (gross * value / 100).round(),
      DiscountType.amount => (value * qty).round(),
    };
    return raw.clamp(0, gross);
  }

  String get valueLabel => type == DiscountType.percent ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%' : 'Rp${value.round()}';

  @override
  List<Object?> get props => [
        id, name, kind, type, value, productId, customerId, visibleInCatalog, start, end, active,
      ];
}
