import 'package:flutter/foundation.dart';

enum AppFlavor {
  carbeat,
  floxcity,
}

class FlavorConfig {
  final AppFlavor flavor;
  final String appName;
  final String packageName;
  final String androidApplicationId;
  final String iosBundleId;
  final String serverUrl;
  final String publicServerUrl;
  final String socketBaseUrl;
  final String appTitle;
  final String appIconPath;

  const FlavorConfig({
    required this.flavor,
    required this.appName,
    required this.packageName,
    required this.androidApplicationId,
    required this.iosBundleId,
    required this.serverUrl,
    required this.publicServerUrl,
    required this.socketBaseUrl,
    required this.appTitle,
    required this.appIconPath,
  });

  static FlavorConfig get current {
    const flavorString = String.fromEnvironment('FLAVOR', defaultValue: 'carbeat');
    final flavor = AppFlavor.values.firstWhere(
      (f) => f.name == flavorString,
      orElse: () => AppFlavor.carbeat,
    );

    return _getConfigForFlavor(flavor);
  }

  static FlavorConfig _getConfigForFlavor(AppFlavor flavor) {
    // LOCAL endpoints (used in debug/profile by default)
    const localServerUrl = 'http://10.206.191.75:100/api/';
    const localPublicServerUrl = 'http://10.206.191.75:100/';
    const localSocketUrl = 'http://10.206.191.75:100/';

    switch (flavor) {
      case AppFlavor.carbeat:
        return FlavorConfig(
          flavor: AppFlavor.carbeat,
          appName: 'Carbeat',
          packageName: 'carbeat',
          androidApplicationId: 'online.carbeat.app',
          iosBundleId: 'online.carbeat.app',
          serverUrl: kReleaseMode
              ? 'https://carbeat.online/api/'
              : localServerUrl,
          publicServerUrl: kReleaseMode
              ? 'https://carbeat.online/'
              : localPublicServerUrl,
          socketBaseUrl: kReleaseMode
              ? 'https://socket.carbeat.online/'
              : localSocketUrl,
          appTitle: 'CarBeat',
          appIconPath: 'assets/icons/app/carbeat.png',
        );

      case AppFlavor.floxcity:
        return FlavorConfig(
          flavor: AppFlavor.floxcity,
          appName: 'FloxCity',
          packageName: 'floxcity',
          androidApplicationId: 'online.floxcity.app',
          iosBundleId: 'online.floxcity.app',
          serverUrl: kReleaseMode
              ? 'https://flox.city/api/'
              : localServerUrl,
          publicServerUrl: kReleaseMode
              ? 'https://flox.city/'
              : localPublicServerUrl,
          socketBaseUrl: kReleaseMode
              ? 'https://socket.flox.city/'
              : localSocketUrl,
          appTitle: 'FloxCity',
          appIconPath: 'assets/icons/app/floxcity.png',
        );
    }
  }
}

