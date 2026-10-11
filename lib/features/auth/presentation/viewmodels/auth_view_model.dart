import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/viewmodel/action_view_model.dart';
import '../../auth_providers.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

class AuthViewModel extends ActionViewModel {
  Future<bool> signIn(String email, String password) =>
      run(() => ref.read(authRepositoryProvider).signIn(email: email, password: password));

  Future<bool> register({
    required String name,
    required String storeName,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) =>
      run(() => ref.read(authRepositoryProvider).registerCustomer(
            name: name,
            storeName: storeName,
            phone: phone,
            address: address,
            email: email,
            password: password,
          ));

  Future<bool> resetPassword(String email) =>
      run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AsyncValue<void>>(AuthViewModel.new);

class UserManagementViewModel extends ActionViewModel {
  Future<bool> changeRole(AppUser user, UserRole role) =>
      run(() => ref.read(userRepositoryProvider).updateRole(user.uid, role));

  Future<bool> setActive(AppUser user, bool active) =>
      run(() => ref.read(userRepositoryProvider).setActive(user.uid, active));
}

final userManagementViewModelProvider =
    NotifierProvider<UserManagementViewModel, AsyncValue<void>>(UserManagementViewModel.new);
