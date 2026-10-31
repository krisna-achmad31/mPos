import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mpos/features/products/data/product_pdf.dart';
import 'package:mpos/features/products/data/product_xlsx.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/domain/product_export.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';

void main() {
  final logo = img.Image(width: 180, height: 60);
  img.fill(logo, color: img.ColorRgb8(23, 63, 82));
  img.drawString(logo, 'MITRA', font: img.arial24, x: 42, y: 18, color: img.ColorRgb8(255, 255, 255));
  final data = ProductExportData(
    products: List.generate(
      65,
      (i) => Product(
        id: 'p$i',
        name: i == 0 ? '=Fanta & Sprite <Botol>' : 'Produk distributor nomor ${i + 1}',
        sku: '00${i + 1}',
        barcode: '08901234$i',
        category: 'Minuman',
        unit: 'botol',
        sellPrice: 7500 + i * 100,
        wholesalePrice: 6500,
        wholesaleMinQty: 12,
        stock: i,
        packs: const [ProductPack(name: 'karton', contents: 24, price: 150000)],
        active: i != 3,
      ),
    ),
    settings: const StoreSettings(
      storeName: 'Mitra & Rekan Distributor',
      address: 'Jl. Gunungsari No. 7A, Kediri, Jawa Timur',
      phone: '081234567890',
      email: 'info@example.com',
      bankInfo: 'Bank: BCA\nRekening: 123456789\nAtas nama: Mitra Rekan',
      invoiceFooter: 'Harga dapat berubah. Hubungi distributor untuk informasi pemesanan.',
    ),
    distributorName: 'Fallback',
    exportedAt: DateTime(2026, 10, 30, 9, 15),
    logoPng: img.encodePng(logo),
  );

  test('Excel memuat kop, logo, data numerik dan header yang dapat difilter', () {
    final bytes = ProductXlsx.build(data);
    final archive = ZipDecoder().decodeBytes(bytes);
    String xml(String name) => utf8.decode(archive.findFile(name)!.content as List<int>);
    final sheet = xml('xl/worksheets/sheet1.xml');
    expect(sheet, contains('Mitra &amp; Rekan Distributor'));
    expect(sheet, contains('info@example.com'));
    expect(sheet, contains('Rekening: 123456789'));
    expect(sheet, contains('<autoFilter ref="A8:M73"/>'));
    expect(sheet, contains('state="frozen"'));
    expect(sheet, contains('<c r="F9" s="3"><v>7500</v></c>'));
    expect(sheet, contains('=Fanta &amp; Sprite &lt;Botol&gt;'));
    expect(sheet, isNot(contains('<f>=Fanta'))); // Nama produk tetap berupa teks, bukan formula.
    expect(sheet, contains('001'));
    expect(sheet, contains('Produk distributor nomor 65'));
    expect(archive.findFile('xl/media/logo.png')!.content, data.logoPng);
    expect(xml('xl/drawings/drawing1.xml'), contains('cy="433333"')); // Logo 3:1 tetap proporsional.
    final out = Platform.environment['PRODUCT_EXPORT_OUT'];
    if (out != null) File('$out/products.xlsx').writeAsBytesSync(bytes);
  });

  test('modal dan nilai stok dihitung tanpa menggandakan bundle atau stok minus', () {
    const p = Product(id: 'p', name: 'Produk', sellPrice: 20000, stock: 10);
    final stockData = ProductExportData(
      products: [
        p,
        const Product(
          id: 'bundle',
          name: 'Bundle',
          sellPrice: 35000,
          stock: 5,
          bundleItems: [BundleItem(productId: 'p', name: 'Produk', qty: 2)],
        ),
        const Product(id: 'jasa', name: 'Jasa', sellPrice: 1000, trackStock: false, stock: 100),
        const Product(id: 'minus', name: 'Minus', sellPrice: 1000, stock: -2),
      ],
      settings: const StoreSettings(),
      distributorName: '',
      exportedAt: DateTime(2026),
      costs: const {
        'p': ProductCost(productId: 'p', buyPrice: 7000, hpp: 8000),
        'minus': ProductCost(productId: 'minus', buyPrice: 500),
      },
    );
    final zip = ZipDecoder().decodeBytes(ProductXlsx.build(stockData));
    final sheet = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(stockData.totalStockValue, 80000);
    expect(sheet, contains('<c r="L9" s="3"><v>8000</v></c>'));
    expect(sheet, contains('<f>MAX(J9,0)*L9</f><v>80000</v>'));
    expect(sheet, contains('<c r="M10" s="3"><v>0</v></c>'));
    expect(sheet, contains('<c r="M11" s="3"><v>0</v></c>'));
    expect(sheet, contains('<f>MAX(J12,0)*L12</f><v>0</v>'));
    expect(sheet, contains('<f>SUM(M9:M12)</f><v>80000</v>'));
    expect(stockData.hasMissingCosts, isFalse);
  });

  test('modal belum tersedia ditandai dan tidak dianggap nilai persediaan lengkap', () {
    expect(data.hasMissingCosts, isTrue);
    final zip = ZipDecoder().decodeBytes(ProductXlsx.build(data));
    final sheet = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(sheet, contains('Total nilai stok (modal belum lengkap)'));
  });

  test('Excel tanpa logo tidak membuat relasi gambar rusak', () {
    final plain = ProductExportData(
      products: const [],
      settings: const StoreSettings(storeName: ''),
      distributorName: 'Distributor cadangan',
      exportedAt: DateTime(2026),
    );
    expect(plain.name, 'Distributor cadangan');
    final archive = ZipDecoder().decodeBytes(ProductXlsx.build(plain));
    expect(archive.findFile('xl/drawings/drawing1.xml'), isNull);
    expect(
      utf8.decode(archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>),
      isNot(contains('<drawing')),
    );
  });

  test('PDF banyak produk dengan kop dan logo berhasil dibuat', () async {
    final bytes = await buildProductPdf(data);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    final out = Platform.environment['PRODUCT_EXPORT_OUT'];
    if (out != null) File('$out/products.pdf').writeAsBytesSync(bytes);
  });

  test('PDF tanpa logo dan produk kosong tetap valid', () async {
    final plain = ProductExportData(
      products: const [],
      settings: const StoreSettings(),
      distributorName: '',
      exportedAt: DateTime(2026),
    );
    final bytes = await buildProductPdf(plain);
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(data.fileName('xlsx'), 'Daftar Produk 20261030-0915.xlsx');
  });
}
