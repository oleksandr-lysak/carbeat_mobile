import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/services/api_services/api_service.dart';

class ClaimService {
  final ApiService _api = ApiService(AppConstants.serverUrl);

  Future<Map<String, dynamic>> getClaimStatus(String token) async {
    return _api.getRequest('public/claim/$token');
  }

  Future<Map<String, dynamic>> sendCode({required int masterId, required String phone}) {
    return _api.postRequest(
      'auth/claim/send_sms',
      {
        'master_id': masterId,
        'phone': phone,
      },
    );
  }

  Future<Map<String, dynamic>> verifyCode({required int masterId, required String phone, required String code}) {
    return _api.postRequest(
      'auth/claim/verify',
      {
        'master_id': masterId,
        'phone': phone,
        'code': code,
      },
    );
  }
}

