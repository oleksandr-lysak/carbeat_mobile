import 'package:carbeat/models/master.dart';

class User {
  final int id;
  final String name;
  final String phone;
  final Master? master;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.master,
  });

  // Створення об'єкта Master з JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      master: json['master'] != null ? Master.fromJson(json['master']) : null,
    );
  }

  // Перетворення об'єкта Master в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'master': master?.toJson(),
    };
  }
}
