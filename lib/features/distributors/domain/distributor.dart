import 'package:equatable/equatable.dart';

/// Satu distributor (tenant). Semua data bisnisnya ada di `distributors/{id}/...`.
class Distributor extends Equatable {
  const Distributor({required this.id, required this.name, this.ownerUid = '', this.phone = '', this.city = ''});

  final String id;
  final String name;
  final String ownerUid;
  final String phone;
  final String city;

  @override
  List<Object?> get props => [id, name, ownerUid, phone, city];
}

abstract interface class DistributorRepository {
  Stream<List<Distributor>> watchAll();

  Stream<Distributor?> watch(String id);

  Future<void> rename(String id, String name);
}
