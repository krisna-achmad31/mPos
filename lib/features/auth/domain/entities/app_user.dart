import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.distributorId = '',
    this.active = true,
    this.storeName = '',
    this.phone = '',
    this.address = '',
    this.cafeId = '',
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;

  /// Distributor tempat akun ini bekerja / berbelanja. Semua data dibaca dari sini.
  final String distributorId;
  final bool active;

  // Data toko, hanya relevan untuk Customer.
  final String storeName;
  final String phone;
  final String address;

  /// POS kopi tempat akun ini bekerja: uid pelanggan pemiliknya (Owner Kopi / Kasir).
  final String cafeId;

  bool get isOwner => role == UserRole.owner;

  /// Nama yang tampil di nota: nama toko bila ada.
  String get displayName => storeName.isNotEmpty ? storeName : name;

  /// Customer yang sedang membuka POS kopinya: akun sama, role Owner Kopi, data di `cafes/{uid}`.
  AppUser asCafeOwner() => AppUser(
        uid: uid,
        name: name,
        email: email,
        role: UserRole.cafeOwner,
        distributorId: distributorId,
        active: active,
        storeName: storeName,
        phone: phone,
        address: address,
        cafeId: uid,
      );

  @override
  List<Object?> get props => [uid, name, email, role, distributorId, active, storeName, phone, address, cafeId];
}
