import '../../../auth/domain/entities/app_user.dart';
import '../entities/change_request.dart';
import '../entities/stock_receipt.dart';

abstract interface class StockRepository {
  /// [createdBy] diisi untuk SPV agar hanya melihat dokumennya sendiri.
  Stream<List<StockReceipt>> watchReceipts({String? createdBy});

  /// Menyimpan stok masuk: stok bertambah, HPP dihitung ulang, mutasi tercatat.
  Future<void> createReceipt(StockReceipt draft, AppUser by);

  /// SPV mengajukan koreksi. Dokumen terkunci sampai Owner memutuskan.
  Future<void> requestChange({
    required StockReceipt receipt,
    required List<StockReceiptItem> newItems,
    required String reason,
    required AppUser by,
  });

  /// Owner mengubah dokumen langsung (tanpa pengajuan).
  Future<void> applyChange({
    required StockReceipt receipt,
    required List<StockReceiptItem> newItems,
    required AppUser by,
  });

  Stream<List<ChangeRequest>> watchChangeRequests({String? requestedBy});

  Future<void> decideChange({
    required ChangeRequest request,
    required bool approve,
    required String note,
    required AppUser by,
  });

  /// Stock opname: stok sistem diganti dengan stok fisik.
  Future<void> adjustStock({
    required String productId,
    required int physicalQty,
    required String note,
    required AppUser by,
  });
}
