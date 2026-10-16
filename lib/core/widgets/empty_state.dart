import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Keadaan kosong yang seragam: ikon dalam bulatan, judul, keterangan, aksi.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: tokens.primaryTint, shape: BoxShape.circle),
              child: Icon(icon, size: 26, color: theme.colorScheme.primary),
            ),
            if (title != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(title!, style: theme.textTheme.titleSmall),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.sm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
