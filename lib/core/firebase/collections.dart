/// Nama koleksi Firestore di satu tempat agar repository dan rules konsisten.
abstract final class Collections {
  static const users = 'users';
  static const products = 'products';
  static const productCosts = 'product_costs';
  static const priceHistory = 'price_history';
  static const stockReceipts = 'stock_receipts';
  static const stockMovements = 'stock_movements';
  static const stockOpnames = 'stock_opnames';
  static const changeRequests = 'change_requests';
  static const discounts = 'discounts';
  static const orders = 'orders';
  static const invoices = 'invoices';
  static const invoiceCosts = 'invoice_costs';
  static const payments = 'payments';
  static const expenses = 'expenses';
  static const counters = 'counters';
  static const settings = 'settings';
  static const auditLogs = 'audit_logs';
}
