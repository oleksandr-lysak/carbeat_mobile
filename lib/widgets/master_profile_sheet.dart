import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/models/user.dart';
import 'package:carbeat/providers/service_provider.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:carbeat/widgets/animated_dropdown_field.dart';
import 'package:carbeat/widgets/animated_text_field.dart';
import 'package:provider/provider.dart';
//import '../services/api_services/auth_service.dart';
import 'app_toast.dart';
import '../utils/phone_validator.dart';
import 'package:image/image.dart' as img;
import 'package:carbeat/utils/image_utils.dart';

class MasterProfileSheet extends StatefulWidget {
  const MasterProfileSheet({super.key});

  @override
  State<MasterProfileSheet> createState() => _MasterProfileSheetState();
}

class _MasterProfileSheetState extends State<MasterProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _descrCtrl = TextEditingController();
  String? _avatarBase64;
  DropdownItem? _selectedService;
  bool _loading = true;
  late int _masterId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await UserService().getUser();
    if (user == null || user.master == null) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      return;
    }
    final m = user.master!;
    _masterId = m.id!;
    _phoneCtrl.text = m.phone;
    _descrCtrl.text = m.description;
    _selectedService = DropdownItem(id: m.specialityId, name: '');

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _descrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serviceProv = Provider.of<ServiceProvider>(context);

    // If список спеціальностей ще не завантажився – покажемо spinkit і
    // зачекаємо, щоб уникнути помилки, коли value не входить до items.
    if (serviceProv.services.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Перетворюємо послуги у список елементів випадаючого меню.
    final List<DropdownItem> serviceItems = serviceProv.services
        .map((s) => DropdownItem(id: s.id, name: s.name))
        .toList();

    // Гарантуємо, що _selectedService входить до списку, інакше додаємо.
    if (_selectedService != null &&
        !serviceItems.any((item) => item.id == _selectedService!.id)) {
      serviceItems.insert(0, _selectedService!);
    }

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Container(
            decoration: BoxDecoration(
              color: Styles().primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).hintColor,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Text(
                            'Профіль майстра',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Styles().titleColor,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close, color: Styles().titleColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Styles().backgroundFormColor,
                        backgroundImage: _avatarBase64 != null
                            ? MemoryImage(base64Decode(_avatarBase64!.split(',').last))
                            : null,
                        child: _avatarBase64 == null
                            ? Icon(Icons.camera_alt, size: 30, color: Styles().primaryColor)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                        color: Styles().primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Styles().backgroundFormColor,
                        hintText: 'Телефон',
                        hintStyle: TextStyle(
                          color: Styles().primaryColor.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descrCtrl,
                      maxLines: 3,
                      style: TextStyle(
                        color: Styles().primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Styles().backgroundFormColor,
                        hintText: 'Опис',
                        hintStyle: TextStyle(
                          color: Styles().primaryColor.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DropdownItem>(
                      value: _selectedService,
                      style: TextStyle(
                        color: Styles().primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Styles().primaryColor,
                      ),
                      dropdownColor: Styles().primaryColor,
                      selectedItemBuilder: (context) => 
                        serviceItems.map((item) => Text(
                          item.name,
                          style: TextStyle(
                            color: Styles().primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        )).toList(),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Styles().backgroundFormColor,
                        hintText: 'Основна послуга',
                        hintStyle: TextStyle(
                          color: Styles().primaryColor.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Styles().primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      items: serviceItems.map((item) => DropdownMenuItem<DropdownItem>(
                        value: item,
                        child: Text(
                          item.name,
                          style: TextStyle(
                            color: Styles().titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedService = val),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles().backgroundFormColor,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _save,
                      child: Text(
                        'Зберегти',
                        style: TextStyle(
                          color: Styles().primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final processed = await _processSquareUnder500kb(bytes);
    setState(() => _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(processed)}');
  }

  // DEPRECATED: use processSquareUnderBytes from image_utils.dart instead
  Future<List<int>> _processSquareUnder500kb(Uint8List inputBytes) async {
    final original = img.decodeImage(inputBytes);
    if (original == null) return inputBytes;

    final int side = original.width < original.height ? original.width : original.height;
    final int offsetX = (original.width - side) ~/ 2;
    final int offsetY = (original.height - side) ~/ 2;
    img.Image current = img.copyCrop(original, x: offsetX, y: offsetY, width: side, height: side);

    const int maxSide = 1024;
    if (current.width > maxSide || current.height > maxSide) {
      current = img.copyResize(current, width: maxSide, height: maxSide);
    }

    const int targetBytes = 500 * 1024;
    int quality = 90;
    List<int> encoded = img.encodeJpg(current, quality: quality);
    while (encoded.length > targetBytes && quality > 30) {
      quality -= 10;
      encoded = img.encodeJpg(current, quality: quality);
    }

    int resizeSide = current.width;
    while (encoded.length > targetBytes && resizeSide > 400) {
      resizeSide = (resizeSide * 0.85).toInt();
      current = img.copyResize(current, width: resizeSide, height: resizeSide);
      quality = (quality - 5).clamp(30, 90);
      encoded = img.encodeJpg(current, quality: quality);
    }

    return encoded;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = ApiService(AppConstants.serverUrl);

    // Ensure avatar prepared and under 500KB
    if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) {
      final raw = base64Decode(_avatarBase64!.split(',').last);
      final processed = await _processSquareUnder500kb(raw);
      _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(processed)}';
    }

    final body = {
      'contact_phone': _phoneCtrl.text,
      'description': _descrCtrl.text,
      'service_id': _selectedService?.id,
      'photo': _avatarBase64,
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

    final res = await api.putRequest('masters/$_masterId', body);
    
    // Check for both 'error' and 'errors' fields
    if (res['error'] == null && res['errors'] == null) {
      AppToast.show('Профіль оновлено', duration: Duration(seconds: 10), background: Colors.green);
      Navigator.pop(context);
      // Refresh local user data after successful update
      final api = ApiService(AppConstants.serverUrl);
      final meResponse = await api.getRequest('auth/me');
      final userJson = meResponse.containsKey('user') ? meResponse['user'] : meResponse;
      final user = User.fromJson(userJson as Map<String, dynamic>);
      await UserService().saveUserData(user);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } else {
      // Handle validation errors
      String errorMessage = 'Error';
      if (res['errors'] != null) {
        final errors = res['errors'] as Map<String, dynamic>;
        if (errors['service_id'] != null) {
          errorMessage = 'Неправильно вибрана послуга';
        } else if (errors.isNotEmpty) {
          errorMessage = errors.values.first.toString();
        }
      } else if (res['error'] != null) {
        errorMessage = res['message'].toString();
      }
      
      AppToast.show(errorMessage, background: Colors.red);
    }
  }
} 