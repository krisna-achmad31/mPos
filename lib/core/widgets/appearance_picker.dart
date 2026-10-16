import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_mode_provider.dart';

/// Pemilih tampilan Terang / Gelap / Ikuti sistem.
///
/// Dipakai di pengaturan dan daftar menu HP. Di sidebar/rail dipakai
/// [AppearanceMenuButton] (hanya ikon) supaya hemat tempat.
class AppearancePicker extends ConsumerWidget {
  const AppearancePicker({super.key, this.compact = false});

  /// true = hanya ikon (tanpa label) agar muat di layar sempit.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: false,
      segments: [
        for (final m in ThemeMode.values)
          ButtonSegment<ThemeMode>(
            value: m,
            icon: Icon(themeModeIcon(m), size: 16),
            label: compact ? null : Text(themeModeLabel(m)),
            tooltip: themeModeLabel(m),
          ),
      ],
      selected: {mode},
      onSelectionChanged: (picked) => ref.read(themeModeProvider.notifier).setMode(picked.first),
    );
  }
}

/// Tombol ikon di sidebar/rail: menu kecil berisi tiga pilihan tampilan.
class AppearanceMenuButton extends ConsumerWidget {
  const AppearanceMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final mode = ref.watch(themeModeProvider);

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Tampilan: ${themeModeLabel(mode)}',
      icon: Icon(themeModeIcon(mode), size: 18),
      onSelected: (m) => ref.read(themeModeProvider.notifier).setMode(m),
      itemBuilder: (context) => [
        for (final m in ThemeMode.values)
          PopupMenuItem<ThemeMode>(
            value: m,
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                Icon(themeModeIcon(m), size: 18, color: tokens.muted),
                Text(themeModeLabel(m)),
                if (m == mode) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
