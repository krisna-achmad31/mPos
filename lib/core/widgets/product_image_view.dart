import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../utils/product_image.dart';

/// Foto produk dengan cadangan aman: tanpa foto / data rusak / gagal dirender -> ikon default.
class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.imageBase64,
    required this.fallbackIcon,
    this.size,
    this.borderRadius = AppRadius.tile,
    this.highlight = false,
    this.enablePreview = false,
  });

  final String imageBase64;
  final IconData fallbackIcon;

  /// null = mengikuti ukuran parent.
  final double? size;
  final double borderRadius;

  /// Latar merah (mis. produk perlu restock) untuk gambar default.
  final bool highlight;
  final bool enablePreview;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeProductImage(imageBase64);
    final placeholder = _Placeholder(icon: fallbackIcon, highlight: highlight, size: size);
    final thumbnail = SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: bytes == null
            ? placeholder
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => placeholder),
      ),
    );
    if (!enablePreview || bytes == null) return thumbnail;
    return Tooltip(
      message: 'Perbesar foto produk',
      child: Semantics(
        button: true,
        label: 'Perbesar foto produk',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 720,
                  height: MediaQuery.sizeOf(context).height * .8,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                        child: Row(
                          children: [
                            Expanded(child: Text('Foto produk', style: Theme.of(context).textTheme.titleMedium)),
                            IconButton(
                              tooltip: 'Tutup pratinjau',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            trackpadScrollCausesScale: true,
                            child: SizedBox.expand(
                              child: Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Center(child: Text('Foto tidak dapat ditampilkan.')),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: thumbnail,
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.highlight, this.size});

  final IconData icon;
  final bool highlight;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final primary = Theme.of(context).colorScheme.primary;
    final background = highlight ? tokens.warningTint : tokens.primaryTint;
    final foreground = highlight ? tokens.warning : primary;

    return ColoredBox(
      color: background,
      child: Center(
        child: Icon(icon, size: size == null ? 40 : size! * 0.5, color: foreground),
      ),
    );
  }
}
