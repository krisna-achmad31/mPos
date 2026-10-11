import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/sales/domain/entities/sales_order.dart';
import 'package:mpos/features/sales/domain/services/order_flow.dart';

void main() {
  const owner = AppUser(uid: 'o', name: 'o', email: '', role: UserRole.owner);
  const courier = AppUser(uid: 'k1', name: 'k', email: '', role: UserRole.spv);
  const otherCourier = AppUser(uid: 'k2', name: 'k', email: '', role: UserRole.spv);
  const customer = AppUser(uid: 'c1', name: 'c', email: '', role: UserRole.customer);
  const otherCustomer = AppUser(uid: 'c2', name: 'c', email: '', role: UserRole.customer);

  SalesOrder order(OrderStatus status, {String? courierId}) => SalesOrder(
        id: 'x',
        customerId: 'c1',
        customerName: '',
        address: '',
        lines: const [],
        status: status,
        createdAt: DateTime(2026),
        courierId: courierId,
      );

  test('Owner menyerahkan ke kurir hanya setelah diproses', () {
    expect(OrderFlow.canMove(order(OrderStatus.processing), OrderStatus.shipped, owner), isTrue);
    expect(OrderFlow.canMove(order(OrderStatus.pending), OrderStatus.shipped, owner), isFalse);
  });

  test('Hanya kurir yang ditugaskan yang bisa menandai terkirim', () {
    final o = order(OrderStatus.shipped, courierId: 'k1');
    expect(OrderFlow.canMove(o, OrderStatus.delivered, courier), isTrue);
    expect(OrderFlow.canMove(o, OrderStatus.delivered, otherCourier), isFalse);
    expect(OrderFlow.canMove(o, OrderStatus.done, courier), isFalse);
  });

  test('Customer pemilik pesanan mengonfirmasi diterima setelah terkirim', () {
    expect(OrderFlow.canMove(order(OrderStatus.delivered), OrderStatus.done, customer), isTrue);
    expect(OrderFlow.canMove(order(OrderStatus.shipped), OrderStatus.done, customer), isFalse);
    expect(OrderFlow.canMove(order(OrderStatus.delivered), OrderStatus.done, otherCustomer), isFalse);
  });
}
