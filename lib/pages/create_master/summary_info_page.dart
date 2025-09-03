import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/models/master.dart';
import 'package:carbeat/models/service.dart';
import 'package:carbeat/models/user.dart';
import 'package:carbeat/services/api_services/auth_service.dart';
import 'package:carbeat/services/location_service.dart';
import 'package:carbeat/services/api_services/service_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/widgets/loading.dart';
import 'package:latlong2/latlong.dart' as lat_lng;
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../widgets/animated_text_field.dart';

class SummaryInfoPage extends StatefulWidget {
  const SummaryInfoPage({super.key});

  @override
  SummaryInfoPageState createState() => SummaryInfoPageState();
}

class SummaryInfoPageState extends State<SummaryInfoPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _verificationCodeController =
      TextEditingController();

  lat_lng.LatLng? _selectedLocation;
  String? _phone;
  String? _name;
  String? _description;
  int? _serviceId;
  String? _photoId;
  String? _address;
  String? _placeId;
  bool isLoading = true;
  File? _photoFile;
  Service? _service;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as List<dynamic>?;
      if (args != null) {
        _selectedLocation = args[0] as lat_lng.LatLng?;
        _phone = args[1] as String?;
        _name = args[2] as String?;
        _description = args[3] as String?;
        _serviceId = args[4] as int?;
        _photoId = args[5] as String?;
      }
      initData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  void initData() async {
    AuthService().sendSms(_phone!);
    if (_selectedLocation != null) {
      _address = await LocationService.getAddressFromCoordinates(
          _selectedLocation!.latitude, _selectedLocation!.longitude);
      _placeId = await LocationService.getPlaceIdFromCoordinates(
          _selectedLocation!.latitude, _selectedLocation!.longitude);
    }
    if (_photoId != null) {
      await _getPhotoFromGallery(_photoId!);
    }
    if (_serviceId != null) {
      _service = await ServiceService.getServiceById(_serviceId!);
    }
    setState(() {
      isLoading = false;
      _animationController.forward();
    });
  }

  Future<void> _getPhotoFromGallery(String photoId) async {
    final albums = await PhotoManager.getAssetPathList(onlyAll: true);

    for (final album in albums) {
      final assets = await album.getAssetListPaged(page: 0, size: 100);
      for (final asset in assets) {
        if (asset.id == photoId) {
          final file = await asset.file;
          setState(() {
            _photoFile = file;
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Loading(),
      );
    } else {
      return Scaffold(
          appBar: AppBar(
            
            title: Text(
              FlutterI18n.translate(context, 'summary_info_page.title'),
              style: TextStyle(color: Styles().titleColor),
            ),
            backgroundColor: Styles().primaryColor,
            iconTheme: IconThemeData(color: Styles().titleColor),
            actionsIconTheme: IconThemeData(color: Styles().titleColor),
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildContent(),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Styles().primaryColor),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
                onPressed: _registerUser,
                child: Text(
                  FlutterI18n.translate(context, 'summary_info_page.register_button'),
                  style: TextStyle(color: Styles().titleColor, fontSize: 24),
                ),
              ),
            ),
          ));
    }
  }

  Widget _buildContent() {
    return ListView(
      children: [
        if (_photoFile != null) _buildPhotoTile(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: AnimatedTextField(
            controller: _verificationCodeController,
            labelText: FlutterI18n.translate(context, 'verification_sms_code'),
            hintText: FlutterI18n.translate(context, 'enter_verification_code'),
            validator: (value) => value?.isEmpty ?? true
                ? FlutterI18n.translate(context, 'required')
                : null,
          ),
        ),
        if (_address != null)
          _buildInfoTile(
              FlutterI18n.translate(context, 'summary_info_page.address'),
              _address!),
        _buildInfoTile(
            FlutterI18n.translate(context, 'summary_info_page.phone'),
            _phone ??
                FlutterI18n.translate(
                    context, 'summary_info_page.not_provided')),
        _buildInfoTile(
            FlutterI18n.translate(context, 'summary_info_page.name'),
            _name ??
                FlutterI18n.translate(
                    context, 'summary_info_page.not_provided')),
        _buildInfoTile(
            FlutterI18n.translate(context, 'summary_info_page.description'),
            _description ??
                FlutterI18n.translate(
                    context, 'summary_info_page.not_provided')),
        _buildInfoTile(
            FlutterI18n.translate(context, 'summary_info_page.specialty'),
            _service?.name ??
                FlutterI18n.translate(
                    context, 'summary_info_page.not_provided')),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: const TextStyle(
              fontSize: 16,
              color: Styles.descriptionColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Styles.textInputColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            FlutterI18n.translate(context, 'summary_info_page.photo'),
            style: const TextStyle(
              fontSize: 16,
              color: Styles.descriptionColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: Styles.textInputColor,
              borderRadius: BorderRadius.circular(Styles.borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _photoFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Styles.borderRadius),
                    child: Image.file(
                      _photoFile!,
                      fit: BoxFit.contain,
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.image,
                      size: 100,
                      color: Styles.subtitleColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _registerUser() async {
    final photo = _photoFile != null ? convertImageToBase64(_photoFile!) : null;
    Map<String, dynamic> request = {
      'sms_code': _verificationCodeController.text,
      'phone': _phone,
      'name': _name,
      'description': _description,
      'service_id': _serviceId,
      'place_id': _placeId,
      'address': _address,
      'latitude': _selectedLocation!.latitude,
      'longitude': _selectedLocation!.longitude,
      'photo': photo,
    };
    setState(() {
      isLoading = true;
    });
    await AuthService().register(request, context);
    User? user = await UserService().getUser();
    if (user != null) {
      if (user.master != null) {
        Master master = user.master!;
        int? masterId = master.id;
        String masterName = master.name;
        Navigator.popAndPushNamed(
          // ignore: use_build_context_synchronously
          context,
          '/booking-page',
          arguments: {
            'masterId': masterId,
            'masterName': masterName,
          },
        );
      }
    }

    Navigator.popAndPushNamed(
      // ignore: use_build_context_synchronously
      context,
      '/home-page',
    );
  }

  String convertImageToBase64(File imageFile) {
    List<int> imageBytes = imageFile.readAsBytesSync();
    return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
  }
}
