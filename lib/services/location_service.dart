import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/services/log_service.dart';

class LocationService {
  static Future<LatLng> getCurrentLocation() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permission = await Geolocator.requestPermission();
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        return LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      LogService.log('Error getting location: $e');
    }

    return const LatLng(50.249198, 30.350024); // Якщо геолокація недоступна
  }

  static Future<String> getCountry(LatLng location) async {
    return _getAddressComponent(
      location,
      componentType: 'country',
    );
  }

  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    return await _fetchGoogleGeocodeData(latitude, longitude);
  }

  static Future<String?> _fetchGoogleGeocodeData(
      double latitude, double longitude) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=${AppConstants.googleMapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      LogService.log('Error fetching geocode data: $e');
    }
    return null;
  }

  static Future<String> _getAddressComponent(
    LatLng location, {
    required String componentType,
  }) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${location.latitude},${location.longitude}&key=${AppConstants.googleMapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          for (var result in data['results']) {
            for (var component in result['address_components']) {
              if (component['types'].contains(componentType)) {
                return component['long_name'];
              }
            }
          }
        }
      }
    } catch (e) {
      LogService.log('Error fetching address component: $e');
    }

    return '';
  }

  static Future<String?> getPlaceIdFromCoordinates(
      double latitude, double longitude) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=${AppConstants.googleMapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Повертаємо place_id першого результату
          return data['results'][0]['place_id'];
        }
      } else {
        LogService.log('Failed to fetch place_id: ${response.statusCode}');
      }
    } catch (e) {
      LogService.log('Error fetching place_id: $e');
    }

    return null;
  }
}
