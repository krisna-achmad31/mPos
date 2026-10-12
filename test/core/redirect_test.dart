import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/router/app_router.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';

void main() {
  AppUser user(UserRole role, {bool active = true}) =>
      AppUser(uid: 'u', name: 'n', email: 'e', role: role, active: active);

  test('belum login diarahkan ke /login', () {
    expect(resolveRedirect(const AsyncData(null), '/owner'), '/login');
    expect(resolveRedirect(const AsyncData(null), '/register'), isNull);
  });

  test('setiap role hanya bisa membuka areanya sendiri', () {
    expect(resolveRedirect(AsyncData(user(UserRole.spv)), '/owner/reports'), '/spv');
    expect(resolveRedirect(AsyncData(user(UserRole.customer)), '/owner'), '/shop');
    expect(resolveRedirect(AsyncData(user(UserRole.owner)), '/owner/reports'), isNull);
  });

  test('POS kopi: Owner Kopi di /cafe, Kasir hanya kasir & riwayat struk', () {
    expect(resolveRedirect(AsyncData(user(UserRole.cafeOwner)), '/login'), '/cafe');
    expect(resolveRedirect(AsyncData(user(UserRole.cafeOwner)), '/cafe/reports'), isNull);
    expect(resolveRedirect(AsyncData(user(UserRole.cafeOwner)), '/shop'), '/cafe');
    expect(resolveRedirect(AsyncData(user(UserRole.cashier)), '/login'), '/cafe/pos');
    expect(resolveRedirect(AsyncData(user(UserRole.cashier)), '/cafe/receipts/x'), isNull);
    expect(resolveRedirect(AsyncData(user(UserRole.cashier)), '/cafe/reports'), '/cafe/pos');
    expect(resolveRedirect(AsyncData(user(UserRole.cashier)), '/cafe'), '/cafe/pos');
    expect(resolveRedirect(AsyncData(user(UserRole.customer)), '/cafe/pos'), '/shop');
  });

  test('akun nonaktif diarahkan ke /inactive', () {
    expect(resolveRedirect(AsyncData(user(UserRole.customer, active: false)), '/shop'), '/inactive');
  });

  test('setelah login, halaman login diarahkan ke beranda role', () {
    expect(resolveRedirect(AsyncData(user(UserRole.owner)), '/login'), '/owner');
  });
}
