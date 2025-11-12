import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:loggme/loggme.dart';

class AppConstants {
  static const String googleMapsApiKey =
      'AIzaSyA6n69rrsvicWBiCrr1n6Paet1Q-YQ7biE';
  static const String mapBoxAccessToken =
      'pk.eyJ1Ijoicm90dGluZyIsImEiOiJjbGFxc2Jxa3oxbTFrM3B0NzJwdTU0OTJtIn0.eQmKPSN5dCp9XxQcxPzJvA';
  static const String mapBoxStyleIdDark = 'cm1dbu9mw00jj01pc25ozbpl6';
  static const String mapBoxStyleIdLight = 'claqrpplh000g14mmffvd0767';
  String mapBoxStyleId = mapBoxStyleIdLight;
  String get urlTemplate =>
      "https://api.mapbox.com/styles/v1/rotting/$mapBoxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$mapBoxAccessToken";

  // LOCAL endpoints (used in debug/profile by default)
  static const String _localServerUrl = 'http://10.162.89.75:100/api/';
  static const String _localPublicServerUrl = 'http://10.162.89.75:100/';
  static const String _localSocketUrl = 'http://10.162.89.75:100/';
  // PROD endpoints (used in release)
  static const String _prodServerUrl = 'https://carbeat.online/api/';
  static const String _prodPublicServerUrl = 'https://carbeat.online/';
  // Socket uses dedicated subdomain in prod
  static const String _prodSocketUrl = 'https://socket.carbeat.online/';

  // Select endpoints based on build mode
  static String get serverUrl => kReleaseMode ? _prodServerUrl : _localServerUrl;
  static String get publicServerUrl =>
      kReleaseMode ? _prodPublicServerUrl : _localPublicServerUrl;
  static String get socketBaseUrl =>
      kReleaseMode ? _prodSocketUrl : _localSocketUrl;

  static const myLocation = LatLng(47.844637, 11.147302);

  static const String defaultLanguage = 'uk';
  static const String appTitle = 'CarBeat';

  final telegramChannelsSenders = <TelegramChannelSender>[
    TelegramChannelSender(
        botId: '7501265558:AAER2lDFq1hgGqZdyh1abjdOOJhwVpp0PKo',
        chatId: '422799222')
  ];

  static List<DropdownMenuItem<String>> languages = const [
    DropdownMenuItem(
      value: 'en',
      child: Text('English'),
    ),
    DropdownMenuItem(
      value: 'de',
      child: Text('Deutsch'),
    ),
    DropdownMenuItem(
      value: 'uk',
      child: Text('Українська'),
    ),
  ];
}
