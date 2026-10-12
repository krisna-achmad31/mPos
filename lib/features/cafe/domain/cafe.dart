import 'package:equatable/equatable.dart';

/// POS kopi milik satu pelanggan distributor. Id = uid pelanggan pemiliknya.
class Cafe extends Equatable {
  const Cafe({
    required this.id,
    required this.name,
    required this.distributorId,
    this.premiumUntil,
    this.lastCode = '',
  });

  final String id;
  final String name;

  /// Distributor tempat pemilik kopi berbelanja; penerbit kode promo premiumnya.
  final String distributorId;

  /// Premium aktif sampai tanggal ini (eksklusif). null = belum pernah aktif.
  final DateTime? premiumUntil;
  final String lastCode;

  bool isPremium(DateTime now) => premiumUntil != null && now.isBefore(premiumUntil!);

  @override
  List<Object?> get props => [id, name, distributorId, premiumUntil, lastCode];
}

/// Bahan baku POS kopi. Stok dan HPP dihitung dalam [unit] (satuan resep, mis. gram / ml).
class Ingredient extends Equatable {
  const Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    this.purchaseUnit = '',
    this.perPurchase = 1,
    this.stock = 0,
    this.avgCost = 0,
    this.minStock = 0,
    this.sourceProductId,
  });

  /// Id bahan yang otomatis dibuat dari produk distributor.
  static String idForProduct(String productId) => 'dist-$productId';

  final String id;
  final String name;

  /// Satuan resep, mis. gram.
  final String unit;

  /// Satuan saat dibeli dari distributor, mis. pack / kg / pcs.
  final String purchaseUnit;

  /// Isi satu [purchaseUnit] dalam [unit], mis. 1 pack = 1000 gram.
  final double perPurchase;

  final double stock;

  /// HPP rata-rata tertimbang per [unit].
  final double avgCost;
  final double minStock;

  /// Produk distributor asal bahan ini (null = bahan yang dibeli di luar distributor).
  final String? sourceProductId;

  bool get fromDistributor => sourceProductId != null;

  bool get isLow => stock <= minStock;

  double get stockValue => stock > 0 ? stock * avgCost : 0;

  /// Mis. "1 pack = 1000 gram"; kosong bila satuannya sama.
  String get conversionLabel =>
      purchaseUnit.isEmpty || (purchaseUnit == unit && perPurchase == 1) ? '' : '1 $purchaseUnit = ${formatQty(perPurchase)} $unit';

  Ingredient copyWith({
    String? name,
    String? unit,
    String? purchaseUnit,
    double? perPurchase,
    double? stock,
    double? avgCost,
    double? minStock,
  }) =>
      Ingredient(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        purchaseUnit: purchaseUnit ?? this.purchaseUnit,
        perPurchase: perPurchase ?? this.perPurchase,
        stock: stock ?? this.stock,
        avgCost: avgCost ?? this.avgCost,
        minStock: minStock ?? this.minStock,
        sourceProductId: sourceProductId,
      );

  @override
  List<Object?> get props => [id, name, unit, purchaseUnit, perPurchase, stock, avgCost, minStock, sourceProductId];
}

/// Pemakaian satu bahan untuk satu porsi menu.
class RecipeLine extends Equatable {
  const RecipeLine({required this.ingredientId, required this.qty});

  final String ingredientId;
  final double qty;

  @override
  List<Object?> get props => [ingredientId, qty];
}

/// Resep satu menu (id = id menu). Resep kosong = menu tidak mengurangi stok bahan.
class Recipe extends Equatable {
  const Recipe({required this.menuId, this.lines = const []});

  final String menuId;
  final List<RecipeLine> lines;

  bool get isEmpty => lines.isEmpty;

  @override
  List<Object?> get props => [menuId, lines];
}

/// Pengaturan khusus POS kopi (kop struk memakai pengaturan toko biasa).
class CafeSettings extends Equatable {
  const CafeSettings({
    this.paperWidth = 58,
    this.printerName = '',
    this.printerAddress = '',
    this.autoPrint = true,
    this.allowNegativeStock = false,
  });

  /// Lebar kertas printer thermal: 58 atau 80 mm.
  final int paperWidth;

  /// Printer Bluetooth terpilih (nama & alamat MAC). Kosong = cetak lewat dialog cetak sistem.
  final String printerName;
  final String printerAddress;

  /// Cetak struk otomatis setelah transaksi tersimpan.
  final bool autoPrint;

  /// true = tetap boleh jual walau stok bahan tercatat kurang (stok jadi minus).
  final bool allowNegativeStock;

  bool get hasBluetoothPrinter => printerAddress.isNotEmpty;

  /// Jumlah karakter per baris struk.
  int get charsPerLine => paperWidth >= 80 ? 48 : 32;

  CafeSettings copyWith({
    int? paperWidth,
    String? printerName,
    String? printerAddress,
    bool? autoPrint,
    bool? allowNegativeStock,
  }) =>
      CafeSettings(
        paperWidth: paperWidth ?? this.paperWidth,
        printerName: printerName ?? this.printerName,
        printerAddress: printerAddress ?? this.printerAddress,
        autoPrint: autoPrint ?? this.autoPrint,
        allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      );

  @override
  List<Object?> get props => [paperWidth, printerName, printerAddress, autoPrint, allowNegativeStock];
}

/// Kode promo premium POS kopi yang diterbitkan distributor untuk pelanggannya.
class PremiumCode extends Equatable {
  const PremiumCode({
    required this.code,
    required this.days,
    this.maxUses = 0,
    this.used = 0,
    this.active = true,
    this.note = '',
    this.createdAt,
  });

  final String code;

  /// Lama premium yang ditambahkan setiap kali kode dipakai.
  final int days;

  /// 0 = tanpa batas.
  final int maxUses;
  final int used;
  final bool active;
  final String note;
  final DateTime? createdAt;

  bool get isUnlimited => maxUses <= 0;

  bool get isExhausted => !isUnlimited && used >= maxUses;

  bool get usable => active && !isExhausted;

  @override
  List<Object?> get props => [code, days, maxUses, used, active, note, createdAt];
}

/// Angka bahan tanpa nol di belakang koma: 18 -> "18", 2.5 -> "2,5".
String formatQty(double value) {
  final rounded = (value * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toString().replaceAll('.', ',');
}
