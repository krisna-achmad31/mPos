import 'package:equatable/equatable.dart';

import 'stock_receipt.dart';

enum ChangeRequestStatus {
  pending('Menunggu'),
  approved('Disetujui'),
  rejected('Ditolak');

  const ChangeRequestStatus(this.label);

  final String label;
}

/// Pengajuan koreksi stok masuk oleh SPV yang menunggu ACC Owner.
class ChangeRequest extends Equatable {
  const ChangeRequest({
    required this.id,
    required this.receiptId,
    required this.receiptDocNo,
    required this.oldItems,
    required this.newItems,
    required this.reason,
    required this.requestedBy,
    required this.requestedByName,
    required this.status,
    required this.createdAt,
    this.decidedByName = '',
    this.decisionNote = '',
  });

  final String id;
  final String receiptId;
  final String receiptDocNo;
  final List<StockReceiptItem> oldItems;
  final List<StockReceiptItem> newItems;
  final String reason;
  final String requestedBy;
  final String requestedByName;
  final ChangeRequestStatus status;
  final DateTime createdAt;
  final String decidedByName;
  final String decisionNote;

  @override
  List<Object?> get props => [id, receiptId, oldItems, newItems, reason, status, decisionNote];
}
