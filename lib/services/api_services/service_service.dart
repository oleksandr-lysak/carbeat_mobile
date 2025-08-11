import 'package:carbeat/models/service.dart';

import '../../constants/app_constants.dart';
import 'api_service.dart';

class ServiceService {
  final ApiService apiService = ApiService(AppConstants.serverUrl);

  Future<List<Service>> fetchServices() async {
    final response = await apiService.getRequest('services');
    List<dynamic> specialtiesJson = response['data'];
    return specialtiesJson.map((json) => Service.fromJson(json)).toList();
  }

  static Future<Service?> getServiceById(int id) async {
    final response =
        await ApiService(AppConstants.serverUrl).getRequest('services/$id');
    return Service.fromJson(response['data']);
  }

  Future<List<Service>> getServiceForMaster(int masterId) async {
    final response =
        await apiService.getRequest('services/get-for-master/$masterId');
    List<dynamic> specialtiesJson = response['data'];
    return specialtiesJson.map((json) => Service.fromJson(json)).toList();
  }
}
