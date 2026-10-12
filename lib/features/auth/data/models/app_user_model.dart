import '../../../../core/firebase/firestore_parsing.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

abstract final class AppUserModel {
  static AppUser fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        name: readString(map['name']),
        email: readString(map['email']),
        role: UserRole.fromName(map['role'] as String?),
        distributorId: readString(map['distributorId']),
        active: readBool(map['active'], fallback: true),
        storeName: readString(map['storeName']),
        phone: readString(map['phone']),
        address: readString(map['address']),
        cafeId: readString(map['cafeId']),
      );

  static Map<String, dynamic> toMap(AppUser user) => {
        'name': user.name,
        'email': user.email,
        'role': user.role.name,
        'distributorId': user.distributorId,
        'active': user.active,
        'storeName': user.storeName,
        'phone': user.phone,
        'address': user.address,
        if (user.cafeId.isNotEmpty) 'cafeId': user.cafeId,
      };
}
