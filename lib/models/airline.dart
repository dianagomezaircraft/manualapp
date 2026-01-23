class Airline {
  final String id;
  final String name;
  final String code;
  final bool active;
  final int usersCount;
  final int manualsCount;

  Airline({
    required this.id,
    required this.name,
    required this.code,
    required this.active,
    required this.usersCount,
    required this.manualsCount,
  });

  factory Airline.fromJson(Map<String, dynamic> json) {
    return Airline(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      active: json['active'],
      usersCount: json['_count']['users'],
      manualsCount: json['_count']['manualChapters'],
    );
  }
}