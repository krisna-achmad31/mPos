import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/products/domain/entities/product.dart';

void main() {
  test('keterangan isi kemasan, kemasan terbesar dulu', () {
    const p = Product(
      id: 'p',
      name: 'Air Mineral',
      unit: 'botol',
      sellPrice: 3500,
      packs: [
        ProductPack(name: 'bal', contents: 6, price: 20000),
        ProductPack(name: 'karton', contents: 24, price: 78000),
      ],
    );
    expect(p.packsLabel, '1 karton = 24 botol · 1 bal = 6 botol');
    expect(const Product(id: 'x', name: 'X', sellPrice: 1).packsLabel, '');
  });

  test('"ball" data lama dibaca sebagai "bal"', () {
    expect(ProductPack.canonicalName(' Ball '), 'bal');
    expect(ProductPack.canonicalName('Sak'), 'sak');
  });
}
