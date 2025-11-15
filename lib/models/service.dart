class Service {
  final int id;
  final String name;
  final int mastersCount;

  Service({required this.id, required this.name, this.mastersCount = 0});

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      mastersCount: (json['masters_count'] is num) ? (json['masters_count'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'masters_count': mastersCount,
    };
  }
}
