import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/viewmodel/action_view_model.dart';
import '../../auth_providers.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../../distributors/domain/distributor.dart';

class AuthViewModel extends ActionViewModel {
  Future<bool> signIn(String email, String password) =>
      run(() => ref.read(authRepositoryProvider).signIn(email: email, password: password));

  Future<bool> register({
    required String distributorId,
    required String name,
    required String storeName,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) =>
      run(() => ref.read(authRepositoryProvider).registerCustomer(
            distributorId: distributorId,
            name: name,
            storeName: storeName,
            phone: phone,
            address: address,
            email: email,
            password: password,
          ));

  /// Mode pilot: masuk tanpa login sebagai [role] di [distributor].
  /// [role] Owner Kopi = Customer uji nomor [customer] yang langsung membuka POS kopinya.
  Future<bool> selectRole(Distributor distributor, UserRole role, {int customer = 1}) => run(() async {
        ref.read(cafeModeProvider.notifier).set(role == UserRole.cafeOwner);
        final loginRole = role == UserRole.cafeOwner ? UserRole.customer : role;
        await ref.read(demoAuthRepositoryProvider).selectRole(distributor, loginRole, customer: customer);
      });

  /// Mode pilot: membuat distributor baru. Mengembalikan null bila gagal.
  Future<Distributor?> createDistributor(String name) async {
    Distributor? created;
    final ok = await run(() async => created = await ref.read(demoAuthRepositoryProvider).createDistributor(name));
    return ok ? created : null;
  }

  Future<bool> registerDistributor({
    required String ownerName,
    required String distributorName,
    required String phone,
    required String email,
    required String password,
  }) =>
      run(() => ref.read(authRepositoryProvider).registerDistributor(
            ownerName: ownerName,
            distributorName: distributorName,
            phone: phone,
            email: email,
            password: password,
          ));

  Future<bool> resetPassword(String email) =>
      run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));

  /// Masuk / keluar POS kopi milik Customer yang sedang login.
  void setCafeMode(bool on) => ref.read(cafeModeProvider.notifier).set(on);

  Future<void> signOut() {
    ref.read(cafeModeProvider.notifier).set(false);
    return ref.read(authRepositoryProvider).signOut();
  }
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
