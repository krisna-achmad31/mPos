import 'package:equatable/equatable.dart';

import 'cart_line.dart';

enum OrderStatus {
  pending('Menunggu'),
  processing('Diproses'),
  /// Owner menyerahkan ke kurir (SPV).
  shipped('Dibawa kurir'),

  /// Kurir menandai sudah sampai.
  delivered('Terkirim'),

  /// Customer mengonfirmasi barang diterima.
  done('Diterima'),
  cancelled('Dibatalkan');

  const OrderStatus(this.label);

  final String label;

  static OrderStatus fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => OrderStatus.pending);

  bool get canCancel => this == pending || this == processing;
}

/// Pesanan dari aplikasi Customer. Harga di sini selalu harga normal.
class SalesOrder extends Equatable {
  const SalesOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.address,
    required this.lines,
    required this.status,
    required this.createdAt,
    this.note = '',
    this.invoiceId,
    this.cancelReason = '',
    this.courierId,
    this.courierName = '',
    this.creditDueDate,
    this.creditPaid = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String address;
  final List<CartLine> lines;
  final OrderStatus status;
  final DateTime createdAt;
  final String note;
  final String? invoiceId;
  final String cancelReason;

  /// SPV yang ditugaskan sebagai kurir.
  final String? courierId;
  final String courierName;

  /// Disalin dari nota saat dijadikan tempo: barang tetap dikirim, bayar paling lambat tanggal ini.
  /// Ada di pesanan karena kurir (SPV) tidak bisa membuka nota.
  final DateTime? creditDueDate;

  /// Tempo sudah dibayar lunas.
  final bool creditPaid;

  bool get isCredit => creditDueDate != null;

  int get subtotal => lines.fold(0, (sum, l) => sum + l.gross);

  @override
  List<Object?> get props =>
      [id, customerId, lines, status, invoiceId, cancelReason, courierId, creditDueDate, creditPaid];
}
