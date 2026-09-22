/// Pure-Dart Stop domain entity.
/// Zero Flutter imports.
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.area,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String area;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'area': area,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
    id: json['id'] as String,
    name: json['name'] as String,
    area: json['area'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Stop &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          area == other.area;

  @override
  int get hashCode => Object.hash(id, name, area);

  @override
  String toString() => 'Stop(id: $id, name: $name, area: $area)';
}
