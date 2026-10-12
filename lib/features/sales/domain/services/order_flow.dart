import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../entities/sales_order.dart';

/// Siapa boleh memindahkan pesanan ke status apa.
///
/// Menunggu → Diproses (Owner, invoice terbit) → Dibawa kurir (Owner memilih SPV)
/// → Terkirim (kurir yang ditugaskan) → Diterima (Customer pemilik pesanan).
abstract final class OrderFlow {
  static bool canMove(SalesOrder order, OrderStatus to, AppUser user) {
    final from = order.status;
    switch (user.role) {
      case UserRole.owner:
        return switch (to) {
          OrderStatus.shipped => from == OrderStatus.processing || from == OrderStatus.shipped,
          // Owner boleh mengambil alih bila kurir / customer lupa menandai.
          OrderStatus.delivered => from == OrderStatus.shipped,
          OrderStatus.done => from == OrderStatus.delivered,
          OrderStatus.cancelled => from.canCancel,
          _ => false,
        };
      case UserRole.spv:
        return to == OrderStatus.delivered && from == OrderStatus.shipped && order.courierId == user.uid;
      case UserRole.cafeOwner || UserRole.cashier:
        return false;
      case UserRole.customer:
        if (order.customerId != user.uid) return false;
        return (to == OrderStatus.done && from == OrderStatus.delivered) ||
            (to == OrderStatus.cancelled && from == OrderStatus.pending);
    }
  }
}
