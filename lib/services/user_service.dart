import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class UserService {
  final String _userKey = 'user';
  Future<void> saveUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    String userJson = jsonEncode(user.toJson());
    await prefs.setString(_userKey, userJson);
  }

  // Отримання токену
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      User user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      return user;
    }
    return null;
  }

  // Видалення токену
  Future<void> deleteUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  Future<bool> isMaster() async {
    User? user = await getUser();
    return user?.master != null; 
  }
}
