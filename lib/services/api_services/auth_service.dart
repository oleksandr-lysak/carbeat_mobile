import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/models/user.dart';
import 'package:carbeat/services/log_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../token_service.dart';
import 'api_service.dart';

class AuthService {
  final ApiService apiService;

  AuthService() : apiService = ApiService(AppConstants.serverUrl);

  Future<bool> confirmLogin(
    String phone,
    int code,
    BuildContext context,
  ) async {
    final response = await apiService.postRequest('auth/verify-otp', {
      'sms_code': code,
      'phone': phone,
    });

    if (response.containsKey('error')) {
      if (!context.mounted) return false;
      final errorMessage = FlutterI18n.translate(context, response['error']);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
      return false;
    }

    final accessToken = response['access_token'];
    final refreshToken = response['refresh_token'];
    final expiresIn = response['expires_in'] is int ? response['expires_in'] as int : null;
    final tokenService = TokenService();
    await tokenService.saveTokens(accessToken, refreshToken, expiresInSeconds: expiresIn);

    // Fetch full user from auth/me to ensure latest fields like master.main_photo
    final me = await apiService.getRequest('auth/me');
    final userJson = me.containsKey('user') ? me['user'] : me;
    final User user = User.fromJson(userJson as Map<String, dynamic>);
    await UserService().saveUserData(user);
    return true;
  }

  Future<void> register(
    Map<String, dynamic> userData,
    BuildContext context,
  ) async {
    try {
      final response = await apiService.postRequest(
        'auth/master-register',
        userData,
      );

      final token = response['token'];
      if (!context.mounted) return;
      final tokenService = Provider.of<TokenService>(context, listen: false);
      final userService = Provider.of<UserService>(context, listen: false);
      await tokenService.saveToken(token);

      // Refresh full user after registration
      final me = await apiService.getRequest('auth/me');
      final freshUserJson = me.containsKey('user') ? me['user'] : me;
      User user = User.fromJson(freshUserJson as Map<String, dynamic>);
      await userService.saveUserData(user);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'];
        if (errors != null) {
          errors.forEach((key, messages) {
            for (var message in messages) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message.toString())));
            }
          });
        } else {
          if (!context.mounted) return;
          final message =
              e.response?.data['message'] ?? 'Невідома помилка валідації';
          LogService.log('Validation error: $message');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      } else {
        if (!context.mounted) return;
        LogService.log('Registration error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка під час реєстрації: $e')),
        );
      }
    }
  }

  Future<bool> sendSms(String phone) async {
    String? appHash;
    try {
      appHash = await SmsAutoFill().getAppSignature;
    } catch (_) {}
    final payload = <String, dynamic>{'phone': phone};
    if (appHash != null && appHash.isNotEmpty) {
      payload['app_hash'] = appHash;
    }
    var result = await apiService.postRequest('auth/request-otp', payload);
    LogService.log('Send SMS result: $result');
    return result['needs_registration'] ?? false;
  }

  Future<void> registerClient(
    String name,
    String phone,
    BuildContext context,
  ) async {
    final response = await apiService.postRequest('auth/client-register', {
      'name': name,
      'phone': phone,
    });
    final token = response['token'];
    final tokenService = TokenService();
    final userService = UserService();
    await tokenService.saveToken(token);
    Map<String, dynamic> data = {
      'id': response['user']['id'],
      'name': response['user']['name'],
      'phone': response['user']['client']['phone'],
    };
    User user = User.fromJson(data);
    await userService.saveUserData(user);
  }

  // Check auth status on app start
  Future<bool> checkAuthStatus() async {
    final tokenService = TokenService();
    final accessToken = await tokenService.getAccessToken();
    if (accessToken == null) return false;

    if (!await tokenService.isTokenValid()) {
      return await apiService.refreshToken();
    }
    return true;
  }

  // Explicit refresh helper (avoid using postRequest to prevent recursion)
  Future<bool> refreshToken() async {
    return apiService.refreshToken();
  }

  // Logout (server-side). Do not auto-delete local tokens here to respect persistent login requirement.
  Future<void> logout() async {
    final refresh = await TokenService().getRefreshToken();
    if (refresh == null || refresh.isEmpty) return;
    await apiService.postRequest('auth/logout', {
      'refresh_token': refresh,
    });
  }
}
