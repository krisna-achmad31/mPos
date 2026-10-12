import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../error/app_exception.dart';

/// Sisi terpanjang foto produk setelah diperkecil.
const productImageMaxSide = 512;

/// Batas base64 per foto. Semua produk dimuat sekaligus di daftar/katalog, dan dokumen Firestore maks 1 MB.
const productImageMaxBase64 = 150 * 1024;

/// Batas file asli yang dipilih (sebelum diperkecil).
const productImageMaxSourceBytes = 15 * 1024 * 1024;

/// Memperkecil foto (JPG/PNG/WebP/…) menjadi JPEG kecil lalu base64.
/// Melempar [AppException] bila file bukan gambar atau tetap terlalu besar.
String encodeProductImage(Uint8List source) {
  if (source.length > productImageMaxSourceBytes) {
    throw const AppException('Ukuran foto maksimal 15 MB.');
  }
  final decoded = img.decodeImage(source);
  if (decoded == null) throw const AppException('File bukan gambar yang didukung (JPG, PNG, WebP).');

  var image = img.bakeOrientation(decoded);
  if (image.width > productImageMaxSide || image.height > productImageMaxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: productImageMaxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: productImageMaxSide, interpolation: img.Interpolation.average);
  }
  // PNG transparan: latar putih agar tidak jadi hitam di JPEG.
  if (image.hasAlpha) {
    final background = img.Image(width: image.width, height: image.height)..clear(img.ColorRgb8(255, 255, 255));
    image = img.compositeImage(background, image);
  }

  for (final quality in const [80, 65, 50]) {
    final encoded = base64Encode(img.encodeJpg(image, quality: quality));
    if (encoded.length <= productImageMaxBase64) return encoded;
  }
  throw const AppException('Foto terlalu detail untuk disimpan. Coba foto lain.');
}

final _cache = <int, Uint8List?>{};

/// Base64 -> bytes. null bila kosong atau rusak (tampilan memakai gambar default).
Uint8List? decodeProductImage(String base64) {
  if (base64.isEmpty) return null;
  final key = Object.hash(base64.length, base64.hashCode);
  return _cache.putIfAbsent(key, () {
    if (_cache.length > 300) _cache.clear();
    try {
      final bytes = base64Decode(base64);
      return bytes.isEmpty ? null : bytes;
    } on FormatException {
      return null;
    }
  });
}
