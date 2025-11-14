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
  final String mainPhoto;
  final String mainThumbUrl;
  final int specialityId;
  final bool isPremium;
  final String? premiumUntil;
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
    required this.mainPhoto,
    required this.specialityId,
    required this.isPremium,
    this.premiumUntil,
    this.services = const [],
    required this.available,
    required this.mainThumbUrl,
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
      mainPhoto: json['main_photo']??'',
      mainThumbUrl: json['main_thumb_url']??'',
      specialityId: json['main_service_id']??0,
      rating: double.parse((json['rating']??0).toString()),
      isPremium: (json['is_premium'] ?? false) == true,
      premiumUntil: json['premium_until'],
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
      'photo': mainPhoto,
      'main_thumb_url': mainThumbUrl,
      'speciality_id': specialityId,
      'is_premium': isPremium,
      'premium_until': premiumUntil,
      'services': services,
    };
  }
}

late Response response;
Dio dio = Dio();

bool error = false; //for error status
String errMsg = ""; //to assing any error message from API/runtime
late Map<String, dynamic> apiData; //for decoded JSON data
