import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../../products/domain/services/price_suggestion.dart';
import '../domain/store_settings.dart';
import '../../../core/firebase/tenant_store.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._store);

  final TenantStore _store;

  DocumentReference<Map<String, dynamic>> get _doc => _store.col(Collections.settings).doc('store');

  /// Logo dipisah dari pengaturan agar `save()` tidak menimpanya dan pengaturan tetap ringan.
  DocumentReference<Map<String, dynamic>> get _brandingDoc => _store.col(Collections.settings).doc('branding');

  @override
  Stream<StoreSettings> watch() => _doc.snapshots().map((snap) {
        final m = snap.data();
        if (m == null) return const StoreSettings();
        return StoreSettings(
          storeName: readString(m['storeName']),
          address: readString(m['address']),
          phone: readString(m['phone']),
          email: readString(m['email']),
          taxEnabled: readBool(m['taxEnabled']),
          taxPercent: readDouble(m['taxPercent']),
          bankInfo: readString(m['bankInfo']),
          receiptFooter: readString(m['receiptFooter']),
          invoiceFooter: readString(m['invoiceFooter']),
          signatureName: readString(m['signatureName']),
          defaultNoteType: readString(m['defaultNoteType']).isEmpty ? 'struk80' : readString(m['defaultNoteType']),
          // Pengaturan lama belum punya margin: pakai bawaan.
          marginPercent: m['marginPercent'] == null ? PriceSuggestion.defaultMarginPercent : readDouble(m['marginPercent']),
          priceRounding: readInt(m['priceRounding']) > 0 ? readInt(m['priceRounding']) : PriceSuggestion.defaultRounding,
        );
      });

  @override
  Future<void> save(StoreSettings s) => _doc.set({
        'storeName': s.storeName,
        'address': s.address,
        'phone': s.phone,
        'email': s.email,
        'taxEnabled': s.taxEnabled,
        'taxPercent': s.taxPercent,
        'bankInfo': s.bankInfo,
        'receiptFooter': s.receiptFooter,
        'invoiceFooter': s.invoiceFooter,
        'signatureName': s.signatureName,
        'defaultNoteType': s.defaultNoteType,
        'marginPercent': s.marginPercent,
        'priceRounding': s.priceRounding,
      });

  @override
  Stream<Uint8List?> watchLogo() => _brandingDoc.snapshots().map((snap) {
        final encoded = readString(snap.data()?['logoPng']);
        if (encoded.isEmpty) return null;
        try {
          return base64Decode(encoded);
        } on FormatException {
          return null;
        }
      });

  @override
  Future<void> saveLogo(Uint8List? png) =>
      _brandingDoc.set({'logoPng': png == null ? FieldValue.delete() : base64Encode(png)}, SetOptions(merge: true));
}
