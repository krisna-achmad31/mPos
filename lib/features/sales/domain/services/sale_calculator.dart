import 'package:equatable/equatable.dart';

import '../../../../core/error/app_exception.dart';
import '../entities/cart_line.dart';

class OrderDiscount extends Equatable {
  const OrderDiscount.amount(this.value) : isPercent = false;
  const OrderDiscount.percent(this.value) : isPercent = true;
  const OrderDiscount.none()
      : value = 0,
        isPercent = false;

  final double value;
  final bool isPercent;

  @override
  List<Object?> get props => [value, isPercent];
}

class SaleTotals extends Equatable {
  const SaleTotals({
    required this.subtotal,
    required this.itemDiscount,
    required this.orderDiscount,
    required this.taxPercent,
    required this.tax,
    required this.total,
  });

  /// Jumlah harga normal × qty.
  final int subtotal;
  final int itemDiscount;
  final int orderDiscount;
  final double taxPercent;
  final int tax;
  final int total;

  int get totalDiscount => itemDiscount + orderDiscount;

  @override
  List<Object?> get props => [subtotal, itemDiscount, orderDiscount, taxPercent, tax, total];
}

enum PaymentMethod {
  cash('Tunai'),
  transfer('Transfer / QRIS'),
  downPayment('DP'),
  credit('Tempo');

  const PaymentMethod(this.label);

  final String label;

  /// DP dan tempo meninggalkan sisa tagihan.
  bool get allowsRemaining => this == downPayment || this == credit;
}

enum PaymentStatus {
  paid('Lunas'),
  partial('Belum lunas'),
  unpaid('Belum bayar');

  const PaymentStatus(this.label);

  final String label;

  static PaymentStatus of({required int paid, required int total}) {
    if (paid >= total) return PaymentStatus.paid;
    return paid > 0 ? PaymentStatus.partial : PaymentStatus.unpaid;
  }
}

class PaymentResult extends Equatable {
  const PaymentResult({required this.paid, required this.change, required this.remaining});

  /// Uang yang tercatat masuk (tanpa kembalian).
  final int paid;
  final int change;
  final int remaining;

  PaymentStatus statusFor(int total) => PaymentStatus.of(paid: paid, total: total);

  @override
  List<Object?> get props => [paid, change, remaining];
}

/// Rumus total: Subtotal − diskon item − diskon nota + pajak.
abstract final class SaleCalculator {
  static SaleTotals totals(
    List<CartLine> lines, {
    OrderDiscount orderDiscount = const OrderDiscount.none(),
    double taxPercent = 0,
  }) {
    final subtotal = lines.fold(0, (sum, l) => sum + l.gross);
    final itemDiscount = lines.fold(0, (sum, l) => sum + l.discountAmount);
    final afterItem = subtotal - itemDiscount;
    final rawOrderDiscount = orderDiscount.isPercent
        ? (afterItem * orderDiscount.value / 100).round()
        : orderDiscount.value.round();
    final orderAmount = rawOrderDiscount.clamp(0, afterItem);
    final taxable = afterItem - orderAmount;
    final tax = (taxable * taxPercent / 100).round();
    return SaleTotals(
      subtotal: subtotal,
      itemDiscount: itemDiscount,
      orderDiscount: orderAmount,
      taxPercent: taxPercent,
      tax: tax,
      total: taxable + tax,
    );
  }

  static PaymentResult pay({required int total, required PaymentMethod method, required int amount}) {
    if (total <= 0) throw const AppException('Total harus lebih dari 0.');
    switch (method) {
      case PaymentMethod.cash:
        if (amount < total) throw const AppException('Uang tunai kurang dari total.');
        return PaymentResult(paid: total, change: amount - total, remaining: 0);
      case PaymentMethod.transfer:
        return PaymentResult(paid: total, change: 0, remaining: 0);
      case PaymentMethod.downPayment:
        if (amount <= 0) throw const AppException('Nominal DP harus lebih dari 0.');
        if (amount >= total) throw const AppException('DP harus lebih kecil dari total. Pilih Tunai/Transfer bila lunas.');
        return PaymentResult(paid: amount, change: 0, remaining: total - amount);
      case PaymentMethod.credit:
        final paid = amount.clamp(0, total - 1);
        return PaymentResult(paid: paid, change: 0, remaining: total - paid);
    }
  }
}
