import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:loggme/loggme.dart';
import 'package:carbeat/config/flavor_config.dart';

class AppConstants {
  static final FlavorConfig flavorConfig = FlavorConfig.current;

  static const String googleMapsApiKey =
      'AIzaSyA6n69rrsvicWBiCrr1n6Paet1Q-YQ7biE';
  static const String mapBoxAccessToken =
      'pk.eyJ1Ijoicm90dGluZyIsImEiOiJjbGFxc2Jxa3oxbTFrM3B0NzJwdTU0OTJtIn0.eQmKPSN5dCp9XxQcxPzJvA';
  static const String mapBoxStyleIdDark = 'cm1dbu9mw00jj01pc25ozbpl6';
  static const String mapBoxStyleIdLight = 'claqrpplh000g14mmffvd0767';
  String mapBoxStyleId = mapBoxStyleIdLight;
  String get urlTemplate =>
      "https://api.mapbox.com/styles/v1/rotting/$mapBoxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$mapBoxAccessToken";

  // Use flavor-specific endpoints
  static String get serverUrl => flavorConfig.serverUrl;
  static String get publicServerUrl => flavorConfig.publicServerUrl;
  static String get socketBaseUrl => flavorConfig.socketBaseUrl;

  static const myLocation = LatLng(47.844637, 11.147302);

  static const String defaultLanguage = 'uk';
  static String get appTitle => flavorConfig.appTitle;

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

  // In-app purchase product IDs
  // Make sure to create these in App Store Connect and Google Play Console
  static const String iosPremiumMonthlyProductId = 'premium_monthly';
  static const String androidPremiumMonthlyProductId = 'carbeat_premium';
}
