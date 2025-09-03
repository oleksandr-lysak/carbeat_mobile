import 'dart:convert';

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
              color: Theme.of(context).scaffoldBackgroundColor,
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
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Styles().primaryColor.withOpacity(.2),
                        backgroundImage: _avatarBase64 != null
                            ? MemoryImage(base64Decode(_avatarBase64!.split(',').last))
                            : null,
                        child: _avatarBase64 == null
                            ? const Icon(Icons.camera_alt, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedTextField(
                      controller: _phoneCtrl,
                      labelText: 'Phone',
                      keyboardType: TextInputType.phone,
                      validator: (val) => !PhoneValidator.validate(val ?? '')
                          ? 'Invalid phone'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AnimatedTextField(
                      controller: _descrCtrl,
                      maxLines: 3,
                      labelText: 'Description',
                    ),
                    const SizedBox(height: 16),
                    AnimatedDropdownField(
                      labelText: 'Main service',
                      hintText: 'Select',
                      items: serviceItems,
                      selectedItem: _selectedService,
                      onChanged: (val) => _selectedService = val,
                      validator: (val) {
                        if (val == null || val.id == 0) {
                          return 'Please select a service';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
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
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() => _avatarBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final api = ApiService(AppConstants.serverUrl);
    final body = {
      'contact_phone': _phoneCtrl.text,
      'description': _descrCtrl.text,
      'service_id': _selectedService?.id,
      'photo': _avatarBase64,
    }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

    final res = await api.putRequest('masters/$_masterId', body);
    
    // Check for both 'error' and 'errors' fields
    if (res['error'] == null && res['errors'] == null) {
      AppToast.show('Profile updated');
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
          errorMessage = 'Invalid service selected';
        } else if (errors.isNotEmpty) {
          errorMessage = errors.values.first.toString();
        }
      } else if (res['error'] != null) {
        errorMessage = res['error'].toString();
      }
      
      AppToast.show(errorMessage, background: Colors.red);
    }
  }
} 