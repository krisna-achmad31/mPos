import 'package:equatable/equatable.dart';

import '../services/sale_calculator.dart';
import 'cart_line.dart';

enum InvoiceSource { online, pos }

class Invoice extends Equatable {
  const Invoice({
    required this.id,
    required this.number,
    required this.source,
    required this.customerName,
    required this.lines,
    required this.totals,
    required this.paid,
    required this.change,
    required this.createdAt,
    this.customerId,
    this.orderId,
    this.salesName = '',
    this.paymentMethod,
    this.createdByName = '',
    this.voided = false,
    this.dueDate,
  });

  final String id;
  final String number;
  final InvoiceSource source;
  final String? customerId;
  final String customerName;
  final String? orderId;
  final String salesName;
  final List<CartLine> lines;
  final SaleTotals totals;
  final int paid;
  final int change;
  final PaymentMethod? paymentMethod;
  final DateTime createdAt;
  final String createdByName;

  /// true bila order dibatalkan setelah nota terbit.
  final bool voided;

  /// Tanggal janji bayar untuk nota tempo. Tetap tersimpan setelah lunas sebagai riwayat.
  final DateTime? dueDate;

  int get remaining => totals.total - paid;

  /// Tempo yang belum lunas (dari kasir metode Tempo, atau dijadikan tempo lewat Catat pelunasan).
  bool get isOpenCredit => !voided && remaining > 0 && (paymentMethod == PaymentMethod.credit || dueDate != null);

  /// Lewat tanggal jatuh tempo dan belum lunas.
  bool isOverdue(DateTime now) {
    final due = dueDate;
    return isOpenCredit && due != null && DateTime(now.year, now.month, now.day).isAfter(due);
  }

  PaymentStatus get paymentStatus => PaymentStatus.of(paid: paid, total: totals.total);

  @override
  List<Object?> get props => [id, number, lines, totals, paid, voided, paymentMethod, dueDate];
}

class PaymentRecord extends Equatable {
  const PaymentRecord({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.at,
    this.byName = '',
    this.isReversal = false,
  });

  final String id;
  final String invoiceId;
  final int amount;
  final PaymentMethod method;
  final DateTime at;
  final String byName;

  /// Pembatalan pembayaran (nominal negatif), mis. nota lunas diubah ke tempo.
  final bool isReversal;

  @override
  List<Object?> get props => [id, invoiceId, amount, method, at];
}

/// HPP per nota, hanya untuk Owner (laporan laba).
class InvoiceCost extends Equatable {
  const InvoiceCost({required this.invoiceId, required this.totalCost, required this.createdAt, this.voided = false});

  final String invoiceId;
  final int totalCost;
  final DateTime createdAt;
  final bool voided;

  @override
  List<Object?> get props => [invoiceId, totalCost, voided];
}
