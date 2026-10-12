import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class StoreSettings extends Equatable {
  const StoreSettings({
    this.storeName = 'Toko Saya',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxEnabled = false,
    this.taxPercent = 11,
    this.bankInfo = '',
    this.receiptFooter = 'Terima kasih',
    this.invoiceFooter = '',
    this.signatureName = '',
    this.defaultNoteType = 'struk80',
  });

  final String storeName;
  final String address;
  final String phone;
  final String email;
  final bool taxEnabled;
  final double taxPercent;

  /// Ditampilkan di invoice / faktur.
  final String bankInfo;
  final String receiptFooter;
  final String invoiceFooter;
  final String signatureName;

  /// struk58 | struk80 | invoice | faktur
  final String defaultNoteType;

  double get effectiveTax => taxEnabled ? taxPercent : 0;

  StoreSettings copyWith({
    String? storeName,
    String? address,
    String? phone,
    String? email,
    bool? taxEnabled,
    double? taxPercent,
    String? bankInfo,
    String? receiptFooter,
    String? invoiceFooter,
    String? signatureName,
    String? defaultNoteType,
  }) =>
      StoreSettings(
        storeName: storeName ?? this.storeName,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        taxEnabled: taxEnabled ?? this.taxEnabled,
        taxPercent: taxPercent ?? this.taxPercent,
        bankInfo: bankInfo ?? this.bankInfo,
        receiptFooter: receiptFooter ?? this.receiptFooter,
        invoiceFooter: invoiceFooter ?? this.invoiceFooter,
        signatureName: signatureName ?? this.signatureName,
        defaultNoteType: defaultNoteType ?? this.defaultNoteType,
      );

  @override
  List<Object?> get props => [
        storeName, address, phone, email, taxEnabled, taxPercent, bankInfo, receiptFooter, invoiceFooter,
        signatureName, defaultNoteType,
      ];
}

abstract interface class SettingsRepository {
  Stream<StoreSettings> watch();

  Future<void> save(StoreSettings settings);

  /// Logo distributor (PNG) untuk invoice; null bila belum diunggah.
  Stream<Uint8List?> watchLogo();

  /// [png] null = hapus logo.
  Future<void> saveLogo(Uint8List? png);
}
