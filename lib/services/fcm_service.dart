import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:carbeat/firebase_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:carbeat/services/log_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/notification_provider.dart';

// Top-level background handler must be a global function
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FCMService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static const String _tokenKey = 'fcm_token';

  // Збереження токену
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Отримання токену
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Видалення токену
  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<void> initializeFCM({
    required BuildContext context,
  }) async {
    // Налаштування обробника для повідомлень у фоновому режимі
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Налаштування обробника для повідомлень, коли аплікація активна
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      LogService.log('Foreground message received: ${message.data}');
      if (!context.mounted) return;
      Provider.of<NotificationsProvider>(context, listen: false)
          .addNotification(message.data);
    });
  }

  static Future<void> requestNotificationPermission() async {
    await _firebaseMessaging.requestPermission();
  }

  // Foreground/background tap handling can be added here if needed
}
