import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/core/utils/product_image.dart';
import 'package:mpos/features/products/data/models/product_model.dart';

void main() {
  test('produk lama tanpa field foto -> tanpa gambar (pakai default)', () {
    final p = ProductModel.fromMap('p1', {'name': 'Gula', 'sellPrice': 1000});
    expect(p.imageBase64, '');
    expect(p.hasImage, isFalse);
    expect(decodeProductImage(p.imageBase64), isNull);
  });

  test('field foto bukan string / rusak tidak membuat error', () {
    expect(ProductModel.fromMap('p1', {'name': 'Gula', 'imageBase64': 123}).hasImage, isFalse);
    expect(decodeProductImage('bukan-base64!!'), isNull);
  });

  test('foto besar diperkecil ke 512 px dan bisa dibaca lagi', () {
    final big = img.Image(width: 2000, height: 1000)..clear(img.ColorRgb8(200, 50, 50));
    final encoded = encodeProductImage(Uint8List.fromList(img.encodePng(big)));
    expect(encoded.length, lessThanOrEqualTo(productImageMaxBase64));
    final back = img.decodeJpg(base64Decode(encoded))!;
    expect(back.width, productImageMaxSide);
    expect(back.height, productImageMaxSide ~/ 2);
    expect(decodeProductImage(encoded), isNotNull);
  });

  test('file bukan gambar ditolak', () {
    expect(() => encodeProductImage(Uint8List.fromList(utf8.encode('halo'))), throwsA(isA<AppException>()));
  });

  test('foto tersimpan lewat toEditableMap', () {
    final p = ProductModel.fromMap('p1', {'name': 'Gula', 'imageBase64': 'abc'});
    expect(ProductModel.toEditableMap(p)['imageBase64'], 'abc');
  });
}
