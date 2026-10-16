import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../auth_providers.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/auth_view_model.dart';

/// Owner mengatur role dan status aktif semua akun (padanan frame `10 · Owner / Pengguna`).
class UsersView extends ConsumerWidget {
  const UsersView({super.key});

  static const _roles = [UserRole.owner, UserRole.spv, UserRole.customer];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final vm = ref.read(userManagementViewModelProvider.notifier);
    final distributor = ref.watch(currentDistributorProvider).value?.name ?? '—';
    ref.listen(userManagementViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    return PageScaffold(
      title: 'Pengguna',
      subtitle: 'Kelola peran dan status akun distributor ini.',
      scrollable: false,
      child: AsyncValueView(
        value: ref.watch(allUsersProvider),
        data: (users) {
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.group_outlined,
              message: 'Belum ada pengguna terdaftar',
              title: 'Belum ada pengguna',
            );
          }
          if (context.deviceClass == DeviceClass.phone) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final user in users)
                  _UserCard(
                    user: user,
                    isMe: user.uid == me.uid,
                    distributor: distributor,
                  ),
              ],
            );
          }
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              SectionCard(
                title: 'Daftar pengguna',
                subtitle: '${users.length} akun terhubung.',
                child: AppDataTable(
                  columns: const ['Nama', 'Peran', 'Email', 'Distributor', 'Status', 'Aksi'],
                  flex: const [4, 3, 4, 3, 2, 2],
                  rows: [
                    for (final user in users)
                      [
                        Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        _RoleDropdown(user: user, isMe: user.uid == me.uid, roles: _roles),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(distributor, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Align(alignment: Alignment.centerLeft, child: _StatusOf(active: user.active)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _ActiveSwitch(
                            user: user,
                            isMe: user.uid == me.uid,
                            onChanged: (v) => vm.setActive(user, v),
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusOf extends StatelessWidget {
  const _StatusOf({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      active ? 'Aktif' : 'Nonaktif',
      tone: active ? BadgeTone.success : BadgeTone.neutral,
      icon: active ? Icons.check_circle_outline : Icons.block,
    );
  }
}

class _ActiveSwitch extends StatelessWidget {
  const _ActiveSwitch({required this.user, required this.isMe, required this.onChanged});

  final AppUser user;
  final bool isMe;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: user.active,
      onChanged: isMe ? null : onChanged,
    );
  }
}

class _RoleDropdown extends ConsumerWidget {
  const _RoleDropdown({required this.user, required this.isMe, required this.roles});

  final AppUser user;
  final bool isMe;
  final List<UserRole> roles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(userManagementViewModelProvider.notifier);
    return DropdownButtonHideUnderline(
      child: DropdownButton<UserRole>(
        value: user.role,
        isDense: true,
        onChanged: isMe ? null : (role) => role == null ? null : vm.changeRole(user, role),
        items: [
          for (final role in roles) DropdownMenuItem(value: role, child: Text(role.label)),
        ],
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user, required this.isMe, required this.distributor});

  final AppUser user;
  final bool isMe;
  final String distributor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final vm = ref.read(userManagementViewModelProvider.notifier);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (isMe) const StatusBadge('Anda', tone: BadgeTone.info),
              _StatusOf(active: user.active),
            ],
          ),
          Text(user.email, style: theme.textTheme.bodySmall),
          Text('Distributor: $distributor', style: theme.textTheme.bodySmall),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: _RoleDropdown(user: user, isMe: isMe, roles: UsersView._roles),
              ),
              _ActiveSwitch(user: user, isMe: isMe, onChanged: (v) => vm.setActive(user, v)),
            ],
          ),
        ],
      ),
    );
  }
}
