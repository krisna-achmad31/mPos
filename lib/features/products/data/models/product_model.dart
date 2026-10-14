import '../../../../core/firebase/firestore_parsing.dart';
import '../../domain/entities/product.dart';

abstract final class ProductModel {
  static Product fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        name: readString(map['name']),
        sku: readString(map['sku']),
        barcode: readString(map['barcode']),
        category: readString(map['category']),
        unit: readString(map['unit']).isEmpty ? 'pcs' : readString(map['unit']),
        sellPrice: readInt(map['sellPrice']),
        wholesalePrice: readInt(map['wholesalePrice']),
        wholesaleMinQty: readInt(map['wholesaleMinQty']),
        minStock: readInt(map['minStock']),
        trackStock: readBool(map['trackStock'], fallback: true),
        stock: readInt(map['stock']),
        active: readBool(map['active'], fallback: true),
        packs: [
          for (final m in readMapList(map['packs']))
            ProductPack(name: readString(m['name']), contents: readInt(m['contents']), price: readInt(m['price'])),
        ],
        // Produk lama tidak punya field ini -> '' -> gambar default.
        imageBase64: readString(map['imageBase64']),
        bundleItems: bundleItemsFromList(map['bundleItems']),
      );

  /// Tanpa field `stock`: stok hanya berubah lewat transaksi stok.
  static Map<String, dynamic> toEditableMap(Product p) => {
        'name': p.name,
        'nameLower': p.name.toLowerCase(),
        'sku': p.sku,
        'barcode': p.barcode,
        'category': p.category,
        'unit': p.unit,
        'sellPrice': p.sellPrice,
        'wholesalePrice': p.wholesalePrice,
        'wholesaleMinQty': p.wholesaleMinQty,
        'minStock': p.minStock,
        // Bundling tidak punya stok sendiri (dihitung dari isinya).
        'trackStock': p.isBundle ? false : p.trackStock,
        'active': p.active,
        'packs': [
          for (final pack in p.packs.where((x) => x.isValid))
            {'name': pack.name.trim(), 'contents': pack.contents, 'price': pack.price},
        ],
        'imageBase64': p.imageBase64,
        'bundleItems': [for (final b in p.bundleItems) bundleItemToMap(b)],
      };

  static List<BundleItem> bundleItemsFromList(Object? list) => [
        for (final m in readMapList(list))
          BundleItem(
            productId: readString(m['productId']),
            name: readString(m['name']),
            qty: readInt(m['qty']),
            unit: readString(m['unit']).isEmpty ? 'pcs' : readString(m['unit']),
            price: readInt(m['price']),
            // Bundling lama belum punya harga per isi: pakai harga normal.
            bundlePrice: m['bundlePrice'] == null ? null : readInt(m['bundlePrice']),
            trackStock: readBool(m['trackStock'], fallback: true),
          ),
      ];

  static Map<String, dynamic> bundleItemToMap(BundleItem b) => {
        'productId': b.productId,
        'name': b.name,
        'qty': b.qty,
        'unit': b.unit,
        'price': b.price,
        'bundlePrice': b.bundlePrice,
        'trackStock': b.trackStock,
      };

  static ProductCost costFromMap(String productId, Map<String, dynamic>? map) => ProductCost(
        productId: productId,
        buyPrice: readInt(map?['buyPrice']),
        hpp: readInt(map?['hpp']),
      );
}
