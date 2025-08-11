import 'package:dio/dio.dart';
import 'package:carbeat/services/language_service.dart';
import 'package:carbeat/services/token_service.dart';
import 'dart:convert';

class ApiService {
  final Dio dio;
  final String apiUrl;

  ApiService(this.apiUrl) : dio = Dio() {
    _initializeHeaders(); // Ініціалізуємо заголовки при створенні екземпляра
  }

  /// Ініціалізує заголовки один раз, включаючи локаль.
  Future<void> _initializeHeaders() async {
    final String locale = await LanguageService.getLanguage() ?? 'en';
    dio.options.headers['locale'] = locale;
    dio.options.headers['Content-Type'] = 'application/json';
    dio.options.headers['Accept'] = 'application/json';
  }

  /// Додає заголовки з токеном, якщо вони ще не були додані.
  Future<void> _addHeaders(Map<String, String>? additionalHeaders) async {
    String? token = await TokenService().getAccessToken();
    Map<String, String> headers = {};

    // Додаємо токен, якщо він є
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Додаємо додаткові заголовки, якщо вони є
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    dio.options.headers.addAll(headers); // Додаємо заголовки до Dio
  }

  /// Переконуємося, що access-токен актуальний: якщо прострочений —
  /// намагаємося оновити через refresh. Після цього додаємо/видаляємо
  /// заголовок Authorization.
  Future<void> _ensureAuthorizedHeaders() async {
    final tokenService = TokenService();
    String? accessToken = await tokenService.getAccessToken();

    // Перевіряємо строк дії токена
    if (accessToken != null && _isTokenExpired(accessToken)) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        accessToken = await tokenService.getAccessToken();
      } else {
        // refresh не спрацював — прибираємо токени, щоб викликати повторний логін
        await tokenService.deleteTokens();
        accessToken = null;
      }
    }

    if (accessToken != null) {
      dio.options.headers['Authorization'] = 'Bearer $accessToken';
    } else {
      dio.options.headers.remove('Authorization');
    }
  }

  /// Простий декодер JWT, щоб перевірити поле exp без сторонніх пакетів.
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
      return true; // у разі будь-якої помилки вважаємо токен простроченим
    }
  }

  Future<Response> _performRequest(Future<Response> Function() requestFn) async {
    await _ensureAuthorizedHeaders();
    Response response;
    try {
      response = await requestFn();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Спробуємо оновити й повторити запит.
        final refreshed = await _refreshToken();
        if (refreshed) {
          await _ensureAuthorizedHeaders();
          return await requestFn();
        } else {
          // refresh не вдався — чистимо токени, щоб змусити користувача перелогінитись
          await TokenService().deleteTokens();
        }
      }
      rethrow;
    }
    return response;
  }

  Future<bool> _refreshToken() async {
    final tokenService = TokenService();
    String? refreshToken = await tokenService.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await dio.post('$apiUrl/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      if (response.statusCode == 200) {
        await tokenService.saveTokens(
          response.data['access_token'],
          response.data['refresh_token'],
        );
        return true;
      }
    } catch (_) {
      // ignore
    }
    await tokenService.deleteTokens();
    return false;
  }

  /// GET запит
  Future<Map<String, dynamic>> getRequest(String endpoint,
      {Map<String, String>? headers}) async {
    String url = '$apiUrl$endpoint';
    try {
      await _addHeaders(headers);
      final response = await _performRequest(() => dio.get(url));

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
            'Failed GET request with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('GET request error($url): $e');
    }
  }

  /// Base method for handling error responses
  Map<String, dynamic> _handleErrorResponse(Response? response) {
    final statusCode = response?.statusCode ?? 0;

    if (statusCode == 500) {
      throw Exception('Internal Server Error (500)');
    }

    dynamic respData = response?.data;
    String message;
    if (respData is Map<String, dynamic>) {
      message = respData['message']?.toString() ?? 'Request error';
    } else {
      message = respData?.toString() ?? 'Request error';
    }

    return {
      'error': true,
      'status': statusCode,
      'message': message,
    };
  }

  /// POST request
  Future<Map<String, dynamic>> postRequest(String endpoint, dynamic data,
      {Map<String, String>? headers}) async {
    String url = '$apiUrl$endpoint';

    try {
      await _addHeaders(headers);
      final response = await _performRequest(() => dio.post(url, data: data));

      if (response.statusCode == 200) {
        return response.data;
      }

      return _handleErrorResponse(response);
    } catch (e) {
      if (e is DioException) {
        return _handleErrorResponse(e.response);
      }

      throw Exception('POST request error($url): $e');
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> putRequest(String endpoint, dynamic data,
      {Map<String, String>? headers}) async {
    String url = '$apiUrl$endpoint';
    try {
      await _addHeaders(headers);
      final response = await _performRequest(() => dio.put(url, data: data));
      if (response.statusCode == 200) {
        return response.data;
      }
      return _handleErrorResponse(response);
    } catch (e) {
      if (e is DioException) {
        return _handleErrorResponse(e.response);
      }
      throw Exception('PUT request error($url): $e');
    }
  }
}
