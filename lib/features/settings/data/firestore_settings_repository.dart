import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firebase/collections.dart';
import '../../../core/firebase/firestore_parsing.dart';
import '../domain/store_settings.dart';
import '../../../core/firebase/tenant_store.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._store);

  final TenantStore _store;

  DocumentReference<Map<String, dynamic>> get _doc => _store.col(Collections.settings).doc('store');

  @override
  Stream<StoreSettings> watch() => _doc.snapshots().map((snap) {
        final m = snap.data();
        if (m == null) return const StoreSettings();
        return StoreSettings(
          storeName: readString(m['storeName']),
          address: readString(m['address']),
          phone: readString(m['phone']),
          taxEnabled: readBool(m['taxEnabled']),
          taxPercent: readDouble(m['taxPercent']),
          bankInfo: readString(m['bankInfo']),
          receiptFooter: readString(m['receiptFooter']),
          invoiceFooter: readString(m['invoiceFooter']),
          signatureName: readString(m['signatureName']),
          defaultNoteType: readString(m['defaultNoteType']).isEmpty ? 'struk80' : readString(m['defaultNoteType']),
        );
      });

  @override
  Future<void> save(StoreSettings s) => _doc.set({
        'storeName': s.storeName,
        'address': s.address,
        'phone': s.phone,
        'taxEnabled': s.taxEnabled,
        'taxPercent': s.taxPercent,
        'bankInfo': s.bankInfo,
        'receiptFooter': s.receiptFooter,
        'invoiceFooter': s.invoiceFooter,
        'signatureName': s.signatureName,
        'defaultNoteType': s.defaultNoteType,
      });
}
