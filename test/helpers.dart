import 'package:mpos/features/products/domain/entities/product.dart';

Product product({
  String id = 'p1',
  String name = 'Minyak 1L',
  int price = 20000,
  int stock = 10,
  bool trackStock = true,
  int wholesalePrice = 0,
  int wholesaleMinQty = 0,
  int minStock = 0,
}) =>
    Product(
      id: id,
      name: name,
      sellPrice: price,
      stock: stock,
      trackStock: trackStock,
      wholesalePrice: wholesalePrice,
      wholesaleMinQty: wholesaleMinQty,
      minStock: minStock,
    );
