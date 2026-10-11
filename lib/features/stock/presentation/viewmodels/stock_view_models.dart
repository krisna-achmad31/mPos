import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/change_request.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../stock_providers.dart';

class StockInState extends Equatable {
  const StockInState({
    this.supplier = '',
    this.docNo = '',
    required this.date,
    this.items = const [],
    this.submission = const AsyncData(null),
  });

  final String supplier;
  final String docNo;
  final DateTime date;
  final List<StockReceiptItem> items;
  final AsyncValue<void> submission;

  int get total => items.fold(0, (sum, i) => sum + i.total);

  StockInState copyWith({
    String? supplier,
    String? docNo,
    DateTime? date,
    List<StockReceiptItem>? items,
    AsyncValue<void>? submission,
  }) =>
      StockInState(
        supplier: supplier ?? this.supplier,
        docNo: docNo ?? this.docNo,
        date: date ?? this.date,
        items: items ?? this.items,
        submission: submission ?? this.submission,
      );

  @override
  List<Object?> get props => [supplier, docNo, date, items, submission];
}

/// Form stok masuk (dipakai SPV dan Owner).
class StockInViewModel extends Notifier<StockInState> {
  @override
  StockInState build() => StockInState(date: DateTime.now());

  void setSupplier(String v) => state = state.copyWith(supplier: v);

  void setDocNo(String v) => state = state.copyWith(docNo: v);

  void setDate(DateTime v) => state = state.copyWith(date: v);

  void addItem(Product product, {required int qty, required int buyPrice}) {
    if (qty <= 0) throw const AppException('Qty harus lebih dari 0.');
    final items = [...state.items];
    final index = items.indexWhere((i) => i.productId == product.id && i.buyPrice == buyPrice);
    if (index >= 0) {
      items[index] = items[index].copyWith(qty: items[index].qty + qty);
    } else {
      items.add(StockReceiptItem(productId: product.id, productName: product.name, qty: qty, buyPrice: buyPrice));
    }
    state = state.copyWith(items: items);
  }

  void removeItem(int index) => state = state.copyWith(items: [...state.items]..removeAt(index));

  Future<bool> submit() async {
    state = state.copyWith(submission: const AsyncLoading());
    final user = ref.read(currentUserProvider);
    final draft = StockReceipt(
      id: '',
      supplier: state.supplier.trim(),
      docNo: state.docNo.trim(),
      date: state.date,
      items: state.items,
    );
    final result = await AsyncValue.guard(() => ref.read(stockRepositoryProvider).createReceipt(draft, user));
    if (!ref.mounted) return false;
    if (result.hasError) {
      state = state.copyWith(submission: result);
      return false;
    }
    state = StockInState(date: DateTime.now());
    return true;
  }
}

final stockInViewModelProvider = NotifierProvider<StockInViewModel, StockInState>(StockInViewModel.new);

class StockActionsViewModel extends ActionViewModel {
  /// SPV mengajukan; Owner langsung menerapkan.
  Future<bool> changeReceipt(StockReceipt receipt, List<StockReceiptItem> newItems, {String reason = ''}) {
    final user = ref.read(currentUserProvider);
    final repo = ref.read(stockRepositoryProvider);
    return run(() => user.isOwner
        ? repo.applyChange(receipt: receipt, newItems: newItems, by: user)
        : repo.requestChange(receipt: receipt, newItems: newItems, reason: reason, by: user));
  }

  Future<bool> decide(ChangeRequest request, {required bool approve, String note = ''}) => run(() => ref
      .read(stockRepositoryProvider)
      .decideChange(request: request, approve: approve, note: note, by: ref.read(currentUserProvider)));

  Future<bool> opname(Product product, int physicalQty, String note) => run(() => ref
      .read(stockRepositoryProvider)
      .adjustStock(productId: product.id, physicalQty: physicalQty, note: note, by: ref.read(currentUserProvider)));
}

final stockActionsViewModelProvider =
    NotifierProvider<StockActionsViewModel, AsyncValue<void>>(StockActionsViewModel.new);
