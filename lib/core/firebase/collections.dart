/// Nama koleksi Firestore di satu tempat agar repository dan rules konsisten.
abstract final class Collections {
  /// Top-level: satu dokumen per distributor; data bisnisnya di subkoleksi.
  static const distributors = 'distributors';

  /// Top-level: profil akun + distributorId + role.
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

  /// Data contoh MODE DEMO laporan; tidak pernah dicampur dengan nota asli.
  static const demoDays = 'demo_days';

  /// Top-level: satu dokumen per POS kopi (id = uid pelanggan pemiliknya); datanya di subkoleksi.
  static const cafes = 'cafes';

  /// POS kopi: bahan baku (stok detail, mis. gram / ml).
  static const ingredients = 'ingredients';

  /// POS kopi: resep per menu (id dokumen = id menu di `products`).
  static const recipes = 'recipes';

  /// Distributor: kode promo aktivasi premium POS kopi; pemakaiannya di subkoleksi [redemptions].
  static const premiumCodes = 'premium_codes';
  static const redemptions = 'redemptions';
}
