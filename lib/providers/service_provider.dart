import 'package:flutter/material.dart';
import 'package:carbeat/models/service.dart';
import 'package:carbeat/services/api_services/service_service.dart';

class ServiceProvider with ChangeNotifier {
  final ServiceService _service;
  List<Service> _services = [];
  bool _isLoading = false;
  String? _errorMessage;

  ServiceProvider(this._service);

  List<Service> get services => _services;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadSpecialties() async {
    _isLoading = true;
    notifyListeners();

    try {
      _services = await _service.fetchServices();
      _services.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
