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
import 'package:sms_autofill/sms_autofill.dart';

import 'package:carbeat/utils/image_utils.dart';
import 'package:carbeat/services/log_service.dart';

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
  bool _isListeningForOtp = false;

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
  File? _processedPhotoFile;
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
    try {
      SmsAutoFill().unregisterListener();
    } catch (_) {}
    super.dispose();
  }

  void initData() async {
    _startOtpListener();
    AuthService().sendSms(_phone!);
    if (_selectedLocation != null) {
      _address = await LocationService.getAddressFromCoordinates(
          _selectedLocation!.latitude, _selectedLocation!.longitude);
      _placeId = await LocationService.getPlaceIdFromCoordinates(
          _selectedLocation!.latitude, _selectedLocation!.longitude);
    }
    if (_photoId != null) {
      await _getPhotoFromGallery(_photoId!);
      if (_photoFile != null) {
        final bytes = await _photoFile!.readAsBytes();
        final processed = await processSquareUnderBytes(bytes);
        final tempDir = Directory.systemTemp;
        final outFile = await File('${tempDir.path}/carbeat_sq_${DateTime.now().millisecondsSinceEpoch}.jpg').create();
        await outFile.writeAsBytes(processed, flush: true);
        _processedPhotoFile = outFile;
      }
    }
    if (_serviceId != null) {
      _service = await ServiceService.getServiceById(_serviceId!);
    }
    setState(() {
      isLoading = false;
      _animationController.forward();
    });
  }

  void _startOtpListener() async {
    if (_isListeningForOtp) return;
    _isListeningForOtp = true;
    try {
      await SmsAutoFill().unregisterListener();
    } catch (_) {}
    try {
      await SmsAutoFill().listenForCode();
      final sig = await SmsAutoFill().getAppSignature;
      if (sig.isNotEmpty) {
        try {
          LogService.log('Android App Signature (registration): $sig');
        } catch (_) {}
      }
    } catch (_) {
      _isListeningForOtp = false;
    }
  }

  Future<void> _getPhotoFromGallery(String photoId) async {
    // Check if photoId is a file path (from ImagePicker) or an asset ID (from PhotoManager)
    final file = File(photoId);
    if (await file.exists()) {
      // It's a file path from ImagePicker
      setState(() {
        _photoFile = file;
      });
      return;
    }
    
    // Otherwise, try to find it in PhotoManager
    try {
      final albums = await PhotoManager.getAssetPathList(onlyAll: true);
      for (final album in albums) {
        final assets = await album.getAssetListPaged(page: 0, size: 100);
        for (final asset in assets) {
          if (asset.id == photoId) {
            final assetFile = await asset.file;
            setState(() {
              _photoFile = assetFile;
            });
            return;
          }
        }
      }
    } catch (e) {
      // PhotoManager might fail on Android 13+ without permissions
      // In this case, photoId should be a file path
      LogService.log('Error loading photo from PhotoManager: $e');
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
              color: Styles().primaryColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildContent(),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: Styles().primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Styles().checkColor),
                  shape: MaterialStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
                onPressed: isLoading ? null : () => _registerUser(),
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
        if (_processedPhotoFile != null || _photoFile != null) _buildPhotoTile(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: PinFieldAutoFill(
            controller: _verificationCodeController,
            currentCode: _verificationCodeController.text,
            codeLength: 4,
            keyboardType: TextInputType.number,
            decoration: UnderlineDecoration(
              colorBuilder: FixedColorBuilder(Colors.white30),
              textStyle: TextStyle(
                color: Styles().titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            onCodeChanged: (code) async {
              if (code == null) return;
              _verificationCodeController.text = code;
              setState(() {});
              if (code.length >= 4 && !isLoading) {
                await _registerUser(autoSubmit: true);
              }
            },
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
            style: TextStyle(
              fontSize: 16,
              color: Styles().titleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Styles().titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile() {
    final File displayFile = _processedPhotoFile ?? _photoFile!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            FlutterI18n.translate(context, 'summary_info_page.photo'),
            style: TextStyle(
              fontSize: 16,
              color: Styles().titleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: Styles().titleColor,
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
            child: ClipRRect(
                    borderRadius: BorderRadius.circular(Styles.borderRadius),
                    child: Image.file(
                displayFile,
                fit: BoxFit.cover,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _registerUser({bool autoSubmit = false}) async {
    // Basic client-side validation to avoid silent errors
    final code = _verificationCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введіть код з SMS')),
      );
      return;
    }
    if (_phone == null || _phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Немає телефону для реєстрації')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть локацію на мапі')),
      );
      return;
    }
    if (_serviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть послугу')),
      );
      return;
    }
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });
    try {
    // Ensure processed image
    if (_processedPhotoFile == null && _photoFile != null) {
      final bytes = await _photoFile!.readAsBytes();
      final processed = await processSquareUnderBytes(bytes);
      final tempDir = Directory.systemTemp;
      final outFile = await File('${tempDir.path}/carbeat_sq_${DateTime.now().millisecondsSinceEpoch}.jpg').create();
      await outFile.writeAsBytes(processed, flush: true);
      _processedPhotoFile = outFile;
    }

    final File? toSend = _processedPhotoFile ?? _photoFile;
    String? photo;
    if (toSend != null) {
      final bytes = await toSend.readAsBytes();
      photo = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } else {
      photo = null;
    }

      Map<String, dynamic> request = {
        'sms_code': code,
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

      await AuthService().register(request, context);
      User? user = await UserService().getUser();
      try {
        await SmsAutoFill().unregisterListener();
        _isListeningForOtp = false;
      } catch (_) {}
      if (user != null && user.master != null) {
        Master master = user.master!;
        int? masterId = master.id;
        String masterName = master.name;
        if (!mounted) return;
        Navigator.popAndPushNamed(
          context,
          '/booking-page',
          arguments: {
            'masterId': masterId,
            'masterName': masterName,
          },
        );
      }

      // Close modal flow by navigating to '/home-page' inside inner Navigator.
      if (!mounted) return;
      Navigator.popAndPushNamed(
        context,
        '/home-page',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка реєстрації: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String convertImageToBase64(File imageFile) {
    List<int> imageBytes = imageFile.readAsBytesSync();
    return 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
  }
}
