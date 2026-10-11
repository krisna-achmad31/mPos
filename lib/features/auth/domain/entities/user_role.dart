enum UserRole {
  owner('Owner'),
  spv('SPV'),
  customer('Customer');

  const UserRole(this.label);

  final String label;

  static UserRole fromName(String? name) =>
      values.firstWhere((role) => role.name == name, orElse: () => UserRole.customer);
}
