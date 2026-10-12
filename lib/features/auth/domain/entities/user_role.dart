enum UserRole {
  owner('Owner'),
  spv('SPV'),
  customer('Customer'),

  /// Pelanggan distributor saat membuka POS kopinya sendiri (akun yang sama dengan [customer]).
  cafeOwner('Owner Kopi'),

  /// Kasir di POS kopi; hanya kasir dan riwayat struk.
  cashier('Kasir');

  const UserRole(this.label);

  final String label;

  /// Role yang bekerja di data POS kopi (`cafes/{cafeId}`), bukan di data distributor.
  bool get isCafe => this == cafeOwner || this == cashier;

  static UserRole fromName(String? name) =>
      values.firstWhere((role) => role.name == name, orElse: () => UserRole.customer);
}
