import 'package:flutter/material.dart';

import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/services/sale_calculator.dart';

/// Nada warna untuk status pesanan online.
BadgeTone toneForOrder(OrderStatus status) => switch (status) {
  OrderStatus.pending => BadgeTone.warning,
  OrderStatus.processing => BadgeTone.info,
  OrderStatus.shipped => BadgeTone.info,
  OrderStatus.delivered => BadgeTone.success,
  OrderStatus.done => BadgeTone.success,
  OrderStatus.cancelled => BadgeTone.danger,
};

/// Nada warna untuk status pembayaran nota.
BadgeTone toneForPayment(PaymentStatus status) => switch (status) {
  PaymentStatus.paid => BadgeTone.success,
  PaymentStatus.partial => BadgeTone.warning,
  PaymentStatus.unpaid => BadgeTone.danger,
};

BadgeTone toneForPaymentMethod(PaymentMethod method) =>
    method.allowsRemaining ? BadgeTone.warning : BadgeTone.neutral;

StatusBadge orderBadge(OrderStatus status) => StatusBadge(status.label, tone: toneForOrder(status));

StatusBadge paymentBadge(PaymentStatus status) => StatusBadge(status.label, tone: toneForPayment(status));

/// Lencana `Tempo` dengan tanggal jatuh tempo.
StatusBadge creditBadge(DateTime dueDate, {bool paid = false, bool overdue = false}) => paid
    ? const StatusBadge('Tempo lunas', tone: BadgeTone.success)
    : StatusBadge(
        overdue ? 'Tempo lewat' : 'Tempo',
        tone: overdue ? BadgeTone.danger : BadgeTone.warning,
        icon: Icons.schedule,
      );
