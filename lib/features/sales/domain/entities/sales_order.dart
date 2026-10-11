import 'package:equatable/equatable.dart';

import 'cart_line.dart';

enum OrderStatus {
  pending('Menunggu'),
  processing('Diproses'),
  shipped('Dikirim'),
  done('Selesai'),
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

  int get subtotal => lines.fold(0, (sum, l) => sum + l.gross);

  @override
  List<Object?> get props => [id, customerId, lines, status, invoiceId, cancelReason];
}
