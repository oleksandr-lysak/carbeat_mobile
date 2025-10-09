import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _remoteConfig = FirebaseRemoteConfig.instance;
    await _remoteConfig.setDefaults(<String, Object>{
      'min_supported_build': 1, // force immediate if below
      'recommended_build': 1, // suggest flexible if below
      'flexible_throttle_hours': 24,
    });
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Use defaults on failure
    }
    _initialized = true;
  }

  int get minSupportedBuild => _remoteConfig.getInt('min_supported_build');
  int get recommendedBuild => _remoteConfig.getInt('recommended_build');
  int get flexibleThrottleHours => _remoteConfig.getInt('flexible_throttle_hours');
}


