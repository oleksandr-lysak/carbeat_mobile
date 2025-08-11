import 'package:flutter/material.dart';

class NotificationsProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> get notifications => List.unmodifiable(_notifications);

  void addNotification(Map<String, dynamic> notification) {
    _notifications.add(notification);
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }
}
