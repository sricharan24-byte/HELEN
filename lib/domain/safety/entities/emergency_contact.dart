/// Pure-Dart EmergencyContact domain entity.
/// Zero Flutter imports.
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
    this.isTrusted = true,
  });

  final String name;
  final String phone;
  final String relation;
  final bool isTrusted;

  bool get isValid => name.trim().isNotEmpty && phone.trim().isNotEmpty;

  Map<String, String> toMap() => {
        'name': name,
        'phone': phone,
        'relation': relation,
      };

  factory EmergencyContact.fromMap(Map<String, String> map) => EmergencyContact(
        name: map['name'] ?? '',
        phone: map['phone'] ?? '',
        relation: map['relation'] ?? 'Trusted',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyContact &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          phone == other.phone &&
          relation == other.relation;

  @override
  int get hashCode => Object.hash(name, phone, relation);

  @override
  String toString() => 'EmergencyContact($name, phone: $phone, relation: $relation)';
}
