import 'dart:convert';

import 'package:carbeat/services/log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  // Save tokens (and optionally expiry)
  Future<void> saveTokens(String accessToken, String refreshToken, {DateTime? expiry, int? expiresInSeconds}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);

    DateTime? expiryToStore = expiry;
    if (expiryToStore == null && expiresInSeconds != null) {
      expiryToStore = DateTime.now().add(Duration(seconds: expiresInSeconds));
    }
    // Fallback to reading exp from JWT if not provided
    expiryToStore ??= _getTokenExpiry(accessToken);

    if (expiryToStore != null) {
      await prefs.setString(_tokenExpiryKey, expiryToStore.toIso8601String());
    } else {
      await prefs.remove(_tokenExpiryKey);
    }

//     await LogService.log('''
// 🔐 TOKENS SAVED
// 📱 Access Token: ${accessToken.substring(0, 20)}...
// ⏰ Access Expires: ${expiryToStore ?? 'Unknown'}
// 🔄 Refresh Token: ${refreshToken.substring(0, 20)}...
// 📅 Saved at: ${DateTime.now().toIso8601String()}
//     ''', type: 'info');
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_refreshTokenKey);

//     if (token != null) {
//       final expiry = _getTokenExpiry(token);
//       final isExpired = _isTokenExpired(token);
//
//       await LogService.log('''
// 🔄 REFRESH TOKEN RETRIEVED
// 📱 Token: ${token.substring(0, 20)}...
// ⏰ Expires: ${expiry ?? 'Unknown'}
// ❌ Is Expired: $isExpired
// 📅 Retrieved at: ${DateTime.now().toIso8601String()}
//       ''', type: 'info');
//     } else {
//       await LogService.log('''
// ❌ REFRESH TOKEN NOT FOUND
// 📅 Checked at: ${DateTime.now().toIso8601String()}
//       ''', type: 'warning');
//     }
    return prefs.getString(_refreshTokenKey);
  }

  // Delete tokens (used only on explicit user actions)
  Future<void> deleteTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
//     await LogService.log('''
// 🗑️ TOKENS DELETED
// 📅 Deleted at: ${DateTime.now().toIso8601String()}
//     ''', type: 'warning');
   }

  // Check if access token is expired
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final payload = json.decode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return true;
      if (!payload.containsKey('exp')) return true;
      final exp = payload['exp'];
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
  }

  // Read access token expiry (if stored)
  Future<DateTime?> getAccessTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryIso = prefs.getString(_tokenExpiryKey);
    if (expiryIso == null) return null;
    try {
      return DateTime.parse(expiryIso);
    } catch (_) {
      return null;
    }
  }

  // Check if access token is currently valid using stored expiry or fallback to JWT exp
  Future<bool> isTokenValid() async {
    final accessToken = await getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return false;

    final storedExpiry = await getAccessTokenExpiry();
    if (storedExpiry != null) {
      return DateTime.now().isBefore(storedExpiry);
    }
    return !_isTokenExpired(accessToken);
  }

  // Extract JWT expiry
  DateTime? _getTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = json.decode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, dynamic>) return null;
      if (!payload.containsKey('exp')) return null;
      final exp = payload['exp'];
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }

  // Backward compatibility
  Future<void> saveToken(String token) async => saveTokens(token, '');
  Future<String?> getToken() async => getAccessToken();
  Future<void> deleteToken() async => deleteTokens();
}
