import '../../../auth/domain/entities/app_user.dart';
import '../entities/cart_line.dart';
import '../entities/invoice.dart';
import '../entities/sales_order.dart';
import '../services/sale_calculator.dart';

abstract interface class SalesRepository {
  // ---- Pesanan online ----
  /// [customerId] untuk Customer, [courierId] untuk SPV (kurir); keduanya null = semua (Owner).
  Stream<List<SalesOrder>> watchOrders({String? customerId, String? courierId});

  Stream<SalesOrder?> watchOrder(String id);

  /// Customer checkout: stok dicek ulang lalu dikunci (dikurangi) dalam satu transaksi.
  Future<String> placeOrder({required AppUser customer, required List<CartLine> lines, String note = ''});

  /// Owner memproses pesanan: nota terbit dengan harga khusus / promo yang sudah diterapkan.
  Future<String> processOrder({
    required SalesOrder order,
    required List<CartLine> pricedLines,
    required OrderDiscount orderDiscount,
    required double taxPercent,
    required AppUser by,
  });

  /// Owner menyerahkan pesanan ke kurir (SPV) → status "Dibawa kurir".
  Future<void> assignCourier({required SalesOrder order, required AppUser courier, required AppUser by});

  /// Pindah status sesuai [OrderFlow] (Terkirim oleh kurir, Diterima oleh customer).
  Future<void> moveStatus({required SalesOrder order, required OrderStatus to, required AppUser by});

  /// Stok dikembalikan; nota (bila ada) ditandai batal.
  Future<void> cancelOrder({required SalesOrder order, required String reason, required AppUser by});

  // ---- Kasir langsung ----
  Future<String> createPosSale({
    required List<CartLine> pricedLines,
    required String? customerId,
    required String customerName,
    required String salesName,
    required OrderDiscount orderDiscount,
    required double taxPercent,
    required PaymentMethod method,
    required int amountGiven,
    required AppUser by,
  });

  // ---- Nota & pembayaran ----
  Stream<List<Invoice>> watchInvoices({String? customerId, DateTime? from, DateTime? to});

  Stream<Invoice?> watchInvoice(String id);

  Stream<List<PaymentRecord>> watchPayments(String invoiceId, {String? customerId});

  Stream<List<PaymentRecord>> watchPaymentsBetween(DateTime from, DateTime to);

  Stream<List<InvoiceCost>> watchInvoiceCosts(DateTime from, DateTime to);

  /// Pelunasan DP / tempo.
  Future<void> addPayment({required Invoice invoice, required int amount, required PaymentMethod method, required AppUser by});

  /// Jadikan sisa tagihan sebagai tempo, dibayar paling lambat [dueDate].
  /// Nota yang sudah lunas: pembayarannya dibatalkan (dicatat sebagai pembayaran negatif) lalu jadi tempo penuh.
  Future<void> setCreditTerm({required Invoice invoice, required DateTime dueDate, required AppUser by});
}
