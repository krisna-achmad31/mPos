import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpos/features/backup/data/backup_codec.dart';

class _Db extends Mock implements FirebaseFirestore {}

void main() {
  test('file backup bolak-balik tanpa mengubah tipe data Firestore', () {
    final snapshot = BackupSnapshot(
      tenantPath: 'distributors/d1',
      createdAt: DateTime.utc(2026, 11, 2),
      root: {'name': 'Toko', 'ownerUid': 'o'},
      collections: {
        'invoices': [
          BackupDoc('i1', {
            'total': 85000,
            'tax': 1.5,
            'createdAt': Timestamp(1793000000, 123000),
            'lines': [
              {'name': 'Fanta', 'qty': 2},
            ],
            'nullable': null,
          }),
        ],
        'premium_codes': [
          BackupDoc(
            'KODE',
            {'used': 1},
            {
              'redemptions': [
                BackupDoc('c1', {'at': Timestamp(1, 0)}),
              ],
            },
          ),
        ],
      },
      users: [
        BackupDoc('o', {'role': 'owner'}),
      ],
    );
    final decoded = BackupCodec.decode(BackupCodec.encode(snapshot), db: _Db());
    expect(decoded.tenantPath, 'distributors/d1');
    expect(decoded.root, snapshot.root);
    final invoice = decoded.collections['invoices']!.single;
    expect(invoice.data, snapshot.collections['invoices']!.single.data);
    expect(invoice.data['createdAt'], isA<Timestamp>());
    expect(invoice.data['tax'], isA<double>());
    expect(decoded.collections['premium_codes']!.single.subcollections['redemptions']!.single.id, 'c1');
    expect(decoded.documentCount, 1 + 1 + 1 + 1 + 1);
  });

  test('file bukan backup ditolak', () {
    expect(() => BackupCodec.decode([1, 2, 3], db: _Db()), throwsA(anything));
  });
}
