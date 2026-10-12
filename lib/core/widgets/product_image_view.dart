import 'package:flutter/material.dart';

import '../utils/product_image.dart';

/// Foto produk dengan cadangan aman: tanpa foto / data rusak / gagal dirender -> ikon default.
class ProductImageView extends StatelessWidget {
  const ProductImageView({
    super.key,
    required this.imageBase64,
    required this.fallbackIcon,
    this.size,
    this.borderRadius = 12,
    this.highlight = false,
  });

  final String imageBase64;
  final IconData fallbackIcon;

  /// null = mengikuti ukuran parent.
  final double? size;
  final double borderRadius;

  /// Latar merah (mis. produk perlu restock) untuk gambar default.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeProductImage(imageBase64);
    final placeholder = _Placeholder(icon: fallbackIcon, highlight: highlight, size: size);
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: bytes == null
            ? placeholder
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => placeholder,
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
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: highlight ? scheme.error : scheme.primaryContainer,
      child: Center(
        child: Icon(
          icon,
          size: size == null ? 40 : size! * 0.5,
          color: highlight ? scheme.onError : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
