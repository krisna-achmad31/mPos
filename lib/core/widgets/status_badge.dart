import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Nada warna lencana status — mengikuti komponen `Status …` di `design_ui.pen`.
enum BadgeTone { neutral, info, success, warning, danger }

/// Lencana status kecil (mis. `Lunas`, `Tempo`, `Dikirim`).
///
/// Padanan desain: kotak radius 6, padding 4/8, teks 11 semibold, latar tint.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// Warna latar & teks untuk tiap nada.
  static (Color background, Color foreground) colorsOf(BuildContext context, BadgeTone tone) {
    final tokens = context.tokens;
    return switch (tone) {
      BadgeTone.info => (tokens.primaryTint, Theme.of(context).colorScheme.primary),
      BadgeTone.success => (tokens.successTint, tokens.success),
      BadgeTone.warning => (tokens.warningTint, tokens.warning),
      BadgeTone.danger => (tokens.dangerTint, tokens.danger),
      BadgeTone.neutral => (tokens.canvas, tokens.muted),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsOf(context, tone);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon != null) Icon(icon, size: 13, color: foreground),
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Titik kecil berwarna untuk indikator stok/status di dalam tabel.
class ToneDot extends StatelessWidget {
  const ToneDot({super.key, required this.tone, this.label, this.showLabel = true});

  final BadgeTone tone;
  final String? label;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final (_, foreground) = StatusBadge.colorsOf(context, tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: foreground, shape: BoxShape.circle)),
        if (showLabel && label != null)
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
