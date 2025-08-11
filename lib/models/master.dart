import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:carbeat/models/service.dart';

class Master {
  final int id;
  final String name;
  final String phone;
  final String address;
  final LatLng location;
  final String description;
  final double rating;
  final String photo;
  final int specialityId;
  final int tariffId;
  List<Service> services;
  bool available = false;

  Master({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.location,
    required this.description,
    required this.rating,
    required this.photo,
    required this.specialityId,
    required this.tariffId,
    this.services = const [],
    required this.available,
  });

  // Створення об'єкта Master з JSON
  factory Master.fromJson(Map<String, dynamic> json) {
    double lng = json['longitude'] is double
        ? json['longitude']
        : double.parse(json['longitude'].toString());
    double lat = json['latitude'] is double
        ? json['latitude']
        : double.parse(json['latitude'].toString());
    return Master(
      id: json['id'] ?? 0,
      name: json['name'],
      phone: json['phone'],
      address: json['address']??'',
      location: LatLng(lat, lng),
      description: json['description'],
      photo: json['main_photo']??'',
      specialityId: json['main_service_id']??0,
      rating: double.parse((json['rating']??0).toString()),
      tariffId: json['tariff_id']??1,
      services: json['services'] != null
          ? List<Service>.from(
              json['services'].map((service) => Service.fromJson(service)))
          : [],
      available: json['available'] ?? false,
    );
  }

  // Перетворення об'єкта Master в JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'description': description,
      'rating': rating,
      'photo': photo,
      'speciality_id': specialityId,
      'tariff_id': tariffId,
      'services': services,
    };
  }
}

late Response response;
Dio dio = Dio();

bool error = false; //for error status
String errMsg = ""; //to assing any error message from API/runtime
late Map<String, dynamic> apiData; //for decoded JSON data
