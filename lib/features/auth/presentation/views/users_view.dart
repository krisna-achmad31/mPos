import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../auth_providers.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/auth_view_model.dart';
import '../../../../core/router/app_shell.dart';

/// Owner mengatur role dan status aktif semua akun.
class UsersView extends ConsumerWidget {
  const UsersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final vm = ref.read(userManagementViewModelProvider.notifier);
    ref.listen(userManagementViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Pengguna')),
      body: AsyncValueView(
        value: ref.watch(allUsersProvider),
        data: (users) => ListView.separated(
          itemCount: users.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final user = users[i];
            final isMe = user.uid == me.uid;
            return ListTile(
              title: Text(user.displayName),
              subtitle: Text('${user.email}${user.phone.isEmpty ? '' : ' · ${user.phone}'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<UserRole>(
                    value: user.role,
                    onChanged: isMe ? null : (role) => role == null ? null : vm.changeRole(user, role),
                    items: [
                      for (final role in [UserRole.owner, UserRole.spv, UserRole.customer]) DropdownMenuItem(value: role, child: Text(role.label)),
                    ],
                  ),
                  Switch(
                    value: user.active,
                    onChanged: isMe ? null : (active) => vm.setActive(user, active),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
