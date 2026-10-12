import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/core/utils/png_logo.dart';

/// PNG minimal: signature + IHDR dengan color type tertentu (tanpa IDAT).
Uint8List png(int colorType) => Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52,
      0, 0, 0, 1, 0, 0, 0, 1, 8, colorType, 0, 0, 0,
      0, 0, 0, 0,
      0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0, 0, 0, 0,
    ]);

void main() {
  test('hanya PNG yang diterima', () {
    expect(() => validateLogoPng(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0])), throwsA(isA<AppException>()));
    validateLogoPng(png(6));
  });

  test('deteksi transparansi', () {
    expect(pngHasTransparency(png(6)), isTrue);
    expect(pngHasTransparency(png(2)), isFalse);
  });

  test('logo terlalu besar ditolak', () {
    final big = Uint8List(maxLogoBytes + 1)..setAll(0, png(6));
    expect(() => validateLogoPng(big), throwsA(isA<AppException>()));
  });
}
