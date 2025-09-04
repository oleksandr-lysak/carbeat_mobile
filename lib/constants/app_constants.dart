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

  //LOCAL_PHYSICAL_DEVICE
  static const String serverUrl = 'http://10.24.19.75:100/api/';
  static const String publicServerUrl = 'http://10.24.19.75:100/';
  //LOCAL_LINUX
  // static const String serverUrl = 'http://localhost:100/api/';
  // static const String publicServerUrl = 'http://localhost:100/';
  //LOCAL_EMULATOR
  // static const String serverUrl = 'http://10.0.2.2:100/api/';
  // static const String publicServerUrl = 'http://10.0.2.2:100/';
  //PROD
  // static const String serverUrl = 'https://carbeat.online/api/';
  // static const String publicServerUrl = 'https://carbeat.online/';

  static const myLocation = LatLng(47.844637, 11.147302);

  static const String defaultLanguage = 'en';
  static const String appTitle = 'Garage the best';

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
