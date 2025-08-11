import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/models/user.dart';
import 'package:carbeat/services/log_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:provider/provider.dart';
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
    final tokenService = TokenService();
    await tokenService.saveTokens(accessToken, refreshToken);

    final int userId = response['user']['id'];
    final String userName = response['user']['name'];
    final masterData = response['user']['master'];
    Map<String, dynamic>? jsonMaster;
    if (masterData != null) {
      jsonMaster = {
        'id': masterData['id'],
        'name': masterData['name'],
        'description': masterData['description'],
        'photo': masterData['photo'],
        'phone': masterData['phone'],
        'address': masterData['address'],
        'services': masterData['services'],
        'speciality_id': masterData['speciality_id'],
        'age': masterData['age'],
        'longitude': masterData['longitude'],
        'latitude': masterData['latitude'],
        'tariff_id': masterData['tariff_id'],
      };
    }
    Map<String, dynamic> jsonUser = {
      'id': userId,
      'name': userName,
      'phone': phone,
      'master': jsonMaster,
    };

    final User user = User.fromJson(jsonUser);
    UserService userService = UserService();
    await userService.saveUserData(user);
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
      User user = User.fromJson(response['user']);
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
    var result = await apiService.postRequest('auth/request-otp', {
      'phone': phone,
    });
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
}
