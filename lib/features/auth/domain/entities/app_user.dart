import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
    this.storeName = '',
    this.phone = '',
    this.address = '',
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final bool active;

  // Data toko, hanya relevan untuk Customer.
  final String storeName;
  final String phone;
  final String address;

  bool get isOwner => role == UserRole.owner;

  /// Nama yang tampil di nota: nama toko bila ada.
  String get displayName => storeName.isNotEmpty ? storeName : name;

  @override
  List<Object?> get props => [uid, name, email, role, active, storeName, phone, address];
}
