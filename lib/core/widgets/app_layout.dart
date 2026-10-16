import 'package:flutter/material.dart';

import '../router/app_shell.dart';
import '../theme/app_tokens.dart';

export '../theme/app_tokens.dart';

/// Label lokasi kerja untuk layar POS Kopi (top bar frame `Kopi / …`).
const cafeWorkspace = 'POS Kopi';

/// Kerangka halaman standar (padanan frame `… / <halaman>` di `design_ui.pen`).
///
/// Struktur: app bar tipis berisi jejak lokasi + status sinkron, lalu
/// *page heading* (judul besar + keterangan + tombol aksi), lalu isi halaman.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.breadcrumb,
    this.workspace = 'Workspace',
    this.actions = const [],
    this.appBarActions = const [],
    this.leading,
    this.child,
    this.maxWidth = 1240,
    this.scrollable = true,
    this.padding,
    this.showSync = true,
  });

  final String title;
  final String? subtitle;
  final String? breadcrumb;

  /// Label lokasi kerja di app bar. Layar POS Kopi memakai `cafeWorkspace`.
  final String workspace;
  final List<Widget> actions;
  final List<Widget> appBarActions;
  final Widget? leading;
  final Widget? child;
  final double maxWidth;
  final bool scrollable;
  final EdgeInsets? padding;
  final bool showSync;

  @override
  Widget build(BuildContext context) {
    final device = context.deviceClass;
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final isWide = device == DeviceClass.desktop;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        leading: leading ?? (isWide ? null : shellMenuButton(context)),
        titleSpacing: isWide ? 24 : null,
        title: Row(
          spacing: 6,
          children: [
            Text(
              workspace,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            Text(
              breadcrumb ?? '/  $title',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.ink,
              ),
            ),
          ],
        ),
        actions: [
          if (showSync && isWide) ...[
            const _SyncIndicator(),
            const SizedBox(width: 12),
          ],
          ...appBarActions,
          const SizedBox(width: 8),
        ],
      ),
      body: _body(context, device),
    );
  }

  Widget _body(BuildContext context, DeviceClass device) {
    final pad =
        padding ??
        (device == DeviceClass.phone
            ? AppSpacing.pagePhone
            : AppSpacing.pageWide);
    final heading = PageHeading(
      title: title,
      subtitle: subtitle,
      actions: actions,
      device: device,
    );

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading,
        const SizedBox(height: AppSpacing.xl),
        if (child != null) ...[
          if (scrollable) child! else Expanded(child: child!),
        ],
      ],
    );

    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: inner,
    );

    if (scrollable) {
      return ListView(
        padding: pad,
        children: [Center(child: content)],
      );
    }

    return Padding(
      padding: pad,
      child: Center(child: content),
    );
  }
}

/// Judul halaman + keterangan + tombol aksi (padanan `Page heading`).
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.device,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final DeviceClass? device;

  @override
  Widget build(BuildContext context) {
    final size = device ?? context.deviceClass;
    final theme = Theme.of(context);
    final titleStyle = switch (size) {
      DeviceClass.desktop => theme.textTheme.displaySmall,
      DeviceClass.tablet => theme.textTheme.headlineMedium,
      DeviceClass.phone => theme.textTheme.headlineSmall,
    };
    final stacked = size == DeviceClass.phone && actions.isNotEmpty;

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.tokens.muted,
              ),
            ),
          ),
      ],
    );

    if (actions.isEmpty) return texts;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          texts,
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        Expanded(child: texts),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: actions,
        ),
      ],
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    return Row(
      spacing: 6,
      children: [
        Icon(Icons.check_circle_outline, size: 16, color: tokens.success),
        Text(
          'Tersinkron',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

/// Kartu bagian putih dengan judul — komponen dasar hampir semua halaman.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.spacing = AppSpacing.md,
    this.bottomMargin = AppSpacing.md,
    this.highlight,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final double spacing;
  final double bottomMargin;

  /// `true` untuk kartu berlatar biru (KPI utama), `null` untuk kartu biasa.
  final bool? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isHighlight = highlight == true;

    // Catatan: memakai Material (bukan Container berwarna) supaya ListTile /
    // SwitchListTile di dalam kartu tetap bisa menggambar latar & efek klik.
    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: Material(
        color: isHighlight
            ? theme.colorScheme.primary
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: isHighlight ? theme.colorScheme.primary : tokens.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            title!,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: isHighlight ? Colors.white : tokens.ink,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isHighlight
                                    ? const Color(0xFFDCE7FF)
                                    : tokens.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              if (title != null) SizedBox(height: spacing),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu angka ringkas (padanan `Daily metrics` / KPI di desain).
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.icon,
    this.highlight = false,
    this.width = 200,
    this.onTap,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final bool highlight;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final primary = theme.colorScheme.primary;
    final onCard = highlight ? Colors.white : tokens.ink;
    final soft = highlight ? const Color(0xFFDCE7FF) : tokens.muted;

    return SizedBox(
      width: width,
      child: Material(
        color: highlight ? primary : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: highlight ? primary : tokens.line),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: soft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (icon != null) Icon(icon, size: 18, color: soft),
                  ],
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onCard,
                    fontSize: 24,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: soft,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris kartu angka: sejajar sama lebar bila ruang cukup, membungkus bila tidak.
class KpiRow extends StatelessWidget {
  const KpiRow({
    super.key,
    required this.children,
    this.tileWidth = 200,
    this.spacing = AppSpacing.md,
  });

  final List<Widget> children;
  final double tileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = children.length * (tileWidth + spacing);
        if (constraints.maxWidth >= needed) {
          return IntrinsicHeight(
            child: Row(
              spacing: spacing,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final child in children) Expanded(child: child)],
            ),
          );
        }
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Baris label–nilai untuk panel rincian.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.tokens.muted,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? context.tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabel ringkas dengan kepala kolom (padanan `Data table` di desain).
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.flex,
    this.onTap,
    this.emptyLabel = 'Belum ada data',
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final List<int>? flex;
  final void Function(int index)? onTap;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TableRow(
          cells: [for (final c in columns) _header(context, c)],
          flex: flex,
          isHeader: true,
        ),
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(i),
            child: _TableRow(
              cells: rows[i],
              flex: flex,
              showDivider: i != rows.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, String label) => Text(
    label.toUpperCase(),
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: 10.5, letterSpacing: 0.4),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.cells,
    this.flex,
    this.isHeader = false,
    this.showDivider = true,
  });

  final List<Widget> cells;
  final List<int>? flex;
  final bool isHeader;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final weights = flex ?? List<int>.filled(cells.length, 1);

    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: tokens.line))
            : null,
      ),
      padding: EdgeInsets.symmetric(vertical: isHeader ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: weights[i],
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == cells.length - 1 ? 0 : AppSpacing.md,
                ),
                child: DefaultTextStyle.merge(
                  style:
                      Theme.of(context).textTheme.bodyMedium ??
                      const TextStyle(),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: cells[i],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
