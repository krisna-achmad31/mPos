import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/router/app_shell.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';

void main() {
  group('sidebarIndexFor', () {
    test('menyorot menu yang cocok dengan alamat', () {
      final items = navFor(UserRole.owner);
      expect(sidebarIndexFor(items, '/owner'), 0);
      expect(items[sidebarIndexFor(items, '/owner')].label, 'Dashboard');
      expect(items[sidebarIndexFor(items, '/owner/pos')].label, 'Kasir');
      expect(items[sidebarIndexFor(items, '/owner/settings')].label, 'Pengaturan');
    });

    test('halaman detail menyorot menu induknya', () {
      final items = navFor(UserRole.owner);
      expect(items[sidebarIndexFor(items, '/owner/invoices/abc')].label, 'Riwayat nota');
      expect(items[sidebarIndexFor(items, '/owner/products/new')].label, 'Produk');
      expect(items[sidebarIndexFor(items, '/owner/products/p1')].label, 'Produk');
    });

    test('menu terpanjang yang menang (bukan menu induk)', () {
      final items = navFor(UserRole.customer);
      expect(items[sidebarIndexFor(items, '/shop/cart')].label, 'Keranjang');
      expect(items[sidebarIndexFor(items, '/shop')].label, 'Katalog');
    });

    test('kasir hanya punya kasir & riwayat struk', () {
      final items = navFor(UserRole.cashier);
      expect(items[sidebarIndexFor(items, '/cafe/pos')].label, 'Kasir');
      expect(items[sidebarIndexFor(items, '/cafe/receipts/r1')].label, 'Riwayat struk');
    });

    test('alamat yang belum dikenal tidak menyorot menu terakhir', () {
      // Dulu `/splash` dan `/login` membuat menu TERAKHIR (Pengaturan) tersorot
      // karena sidebar memakai alamat peramban yang belum diperbarui router.
      final items = navFor(UserRole.owner);
      expect(sidebarIndexFor(items, '/splash'), -1);
      expect(sidebarIndexFor(items, '/login'), -1);
      expect(sidebarIndexFor(items, ''), -1);
      expect(sidebarIndexFor(items, '/owner-lain'), -1);
    });
  });
}
