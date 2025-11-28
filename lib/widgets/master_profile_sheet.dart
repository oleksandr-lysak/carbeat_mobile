import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/models/user.dart';
import 'package:carbeat/models/master.dart';
import 'package:carbeat/providers/service_provider.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:carbeat/widgets/animated_dropdown_field.dart';
import 'package:provider/provider.dart';
import 'package:carbeat/services/api_services/auth_service.dart';
import 'package:carbeat/services/token_service.dart';
import 'package:carbeat/services/log_service.dart';
import 'app_toast.dart';
import 'package:image/image.dart' as img;
import 'package:carbeat/pages/premium/premium_page.dart';

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
  bool _loadingDetails = true;
  late int _masterId;

  // Details
  List<Map<String, dynamic>> _gallery = [];
  List<Map<String, dynamic>> _reviews = [];
  Set<int> _additionalServiceIds = {};
  String _mainPhotoPath = '';
  bool _uploading = false;
  double _uploadProgress = 0.0;
  // subscription-related limits
  int _maxPhotos = 3;
  int _maxDescription = 200;
  int _maxServices = 2;

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
    final Master m = user.master as Master;
    _masterId = m.id;
    _phoneCtrl.text = m.phone;
    _descrCtrl.text = m.description;
    _mainPhotoPath = m.mainPhoto;
    _selectedService = DropdownItem(id: m.specialityId, name: '');

    setState(() => _loading = false);

    // Fetch full details for gallery/services/reviews
    try {
      final api = ApiService(AppConstants.serverUrl);
      final res = await api.getRequest('masters/$_masterId');
      final data = res['data'] ?? res;
      final photos = (data['photos'] is List) ? (data['photos'] as List) : [];
      _gallery = photos
          .map<Map<String, dynamic>>((p) => {
                'id': (p['id'] as num).toInt(),
                'url': (p['url'] ?? '').toString(),
              })
          .where((m) => (m['url'] as String).isNotEmpty)
          .toList();
      final services = (data['services'] is List) ? (data['services'] as List) : [];
      _additionalServiceIds = services
          .where((s) => (s['is_primary']?.toString() ?? 'false') != 'true')
          .map<int>((s) => (s['id'] as num).toInt())
          .toSet();
      final reviews = (data['reviews'] is List) ? (data['reviews'] as List) : [];
      _reviews = reviews.map<Map<String, dynamic>>((r) => (r as Map<String, dynamic>)).toList();
      // Update main photo and main service id from details if present
      final String mainPhoto = (data['main_photo'] ?? '').toString();
      if (mainPhoto.isNotEmpty) _mainPhotoPath = mainPhoto;
      final int mainServiceId = (data['main_service_id'] is num) ? (data['main_service_id'] as num).toInt() : _selectedService!.id;
      _selectedService = DropdownItem(id: mainServiceId, name: _selectedService!.name);
    } catch (_) {
      // ignore
    }
    // Fetch limits/status
    try {
      final statusRes = await ApiService(AppConstants.serverUrl).getRequest('user/status');
      final s = statusRes['data'] ?? statusRes;
      _maxPhotos = (s['max_photos'] is num) ? (s['max_photos'] as num).toInt() : _maxPhotos;
      _maxDescription = (s['max_description'] is num) ? (s['max_description'] as num).toInt() : _maxDescription;
      _maxServices = (s['max_services'] is num) ? (s['max_services'] as num).toInt() : _maxServices;
    } catch (_) {
      // ignore
    }
    if (mounted) setState(() => _loadingDetails = false);
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

    // Побудувати локальне значення з правильною назвою без setState
    DropdownItem? currentValue;
    if (_selectedService != null) {
      final match = serviceItems.firstWhere(
        (it) => it.id == _selectedService!.id,
        orElse: () => DropdownItem(id: _selectedService!.id, name: ''),
      );
      currentValue = DropdownItem(id: _selectedService!.id, name: match.name.isNotEmpty ? match.name : '');
    }
    // Сформувати список елементів, що містить також currentValue, якщо такого ще немає
    final List<DropdownItem> itemsWithSelected = List<DropdownItem>.from(serviceItems);
    if (currentValue != null && !itemsWithSelected.any((it) => it.id == currentValue!.id)) {
      itemsWithSelected.insert(0, currentValue);
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
                            icon: const Icon(Icons.check, color: Colors.greenAccent),
                            onPressed: _save,
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Styles().titleColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: Styles().backgroundFormColor,
                            backgroundImage: _avatarBase64 != null
                                ? MemoryImage(base64Decode(_avatarBase64!.split(',').last))
                                : (_mainPhotoPath.isNotEmpty
                                    ? NetworkImage(_buildUrl(_mainPhotoPath))
                                    : null) as ImageProvider<Object>?,
                            child: _avatarBase64 == null && _mainPhotoPath.isEmpty
                                ? Icon(Icons.camera_alt, size: 30, color: Styles().primaryColor)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(10, 40),
                            side: BorderSide(color: Styles().checkColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PremiumPage()),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Оформити Premium',
                                style: TextStyle(
                                  color: Styles().titleColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      onChanged: (_) => setState(() {}),
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
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_descrCtrl.text.length} / $_maxDescription',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DropdownItem>(
                      value: currentValue,
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
                        itemsWithSelected.map((item) => Text(
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
                      items: itemsWithSelected.map((item) => DropdownMenuItem<DropdownItem>(
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Styles().primaryColor,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _openAdditionalServicesDialog,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.design_services, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Додаткові послуги',
                                  style: TextStyle(
                                    color: Styles().titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Styles().primaryColor,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _addGalleryPhotos,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_a_photo, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  'Додати фото',
                                  style: TextStyle(
                                    color: Styles().titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Моя галерея',
                        style: TextStyle(
                          color: Styles().titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (_uploading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: LinearProgressIndicator(
                          value: _uploadProgress > 0 && _uploadProgress <= 1 ? _uploadProgress : null,
                          backgroundColor: Styles().backgroundFormColor,
                          color: Styles().primaryColor,
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildGalleryGrid(),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Мої відгуки',
                        style: TextStyle(
                          color: Styles().titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingDetails)
                      const Center(child: CircularProgressIndicator())
                    else if (_reviews.isEmpty)
                      Text('Поки що немає відгуків', style: const TextStyle(color: Styles.descriptionColor))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final r = _reviews[index];
                          final user = r['user'] as Map<String, dynamic>?;
                          final double rr = (r['rating'] is num) ? (r['rating'] as num).toDouble() : 0;
                          return ListTile(
                            title: Text(user?['name']?.toString() ?? 'Анонім', style: TextStyle(color: Styles().titleColor)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(children: List.generate(5, (i) => Icon(i < rr ? Icons.star : Icons.star_border, size: 16, color: i < rr ? Styles().titleColor : Styles.descriptionColor))),
                                const SizedBox(height: 6),
                                Text(r['review']?.toString() ?? '', style: const TextStyle(color: Styles.descriptionColor)),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                  // Logout section
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.transparent,
                      ),
                      onPressed: _logout,
                      label: Text(
                        'Вийти з акаунту',
                        style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
  }

  String _buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConstants.publicServerUrl.endsWith('/')
        ? AppConstants.publicServerUrl.substring(0, AppConstants.publicServerUrl.length - 1)
        : AppConstants.publicServerUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  Future<void> _pickAvatar() async {
    // Для камери/галереї: запит дозволів дружньо
    final ok = await _ensurePhotosPermission();
    if (!ok) return;
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

  Future<void> _addGalleryPhotos() async {
    final ok = await _ensurePhotosPermission();
    if (!ok) return;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return;

    // Immediately show uploading indicator to provide instant feedback
    if (mounted) {
      setState(() {
        _uploading = true;
        _uploadProgress = 0.0; // indeterminate while preparing images
      });
    }

    bool allUploaded = false;
    try {
      // Prepare base64 with prefix and chunk into max 10 per request
      List<String> payload = [];
      for (final x in picked) {
        final bytes = await x.readAsBytes();
        final processed = await _processSquareUnder500kb(bytes);
        final b64 = base64Encode(processed);
        // Assume jpeg for simplicity; can branch by extension if needed
        payload.add('data:image/jpeg;base64,$b64');
      }

      final api = ApiService(AppConstants.serverUrl);
      int sent = 0;
      while (sent < payload.length) {
        final chunk = payload.sublist(sent, (sent + 10) > payload.length ? payload.length : sent + 10);
        Map<String, dynamic> res;
        try {
          res = await api.postRequest('masters/$_masterId/gallery', {
            'photos': chunk,
          });
        } catch (e) {
          // Network / DioException without response
          await LogService.log('Gallery upload failed (exception) for master $_masterId: $e');
          AppToast.show('Помилка завантаження фото', background: Colors.red);
          break;
        }
        final Map<String, dynamic> responseData = (res['data'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(res['data'] as Map<String, dynamic>)
            : Map<String, dynamic>.from(res);
        final status = (responseData['status'] is num)
            ? (responseData['status'] as num).toInt()
            : ((res['status'] is num) ? (res['status'] as num).toInt() : 200);
        final error = responseData['error'] ?? res['error'];
        final messageRaw = responseData['message'] ?? res['message'];
        if ((status == 403 || error == 'photos_limit') &&
            (responseData['upgrade_required'] == true || responseData['limit'] != null)) {
          final int? limit =
              responseData['limit'] is num ? (responseData['limit'] as num).toInt() : null;
          await _showUpgradeDialog(
            title: 'Досягнуто ліміту фото',
            message: limit != null
                ? 'Ви вже завантажили максимум ($limit) фото. Оформіть Premium, щоб додати більше.'
                : 'Ви досягли ліміту фото. Оновіть профіль до Premium, щоб додати більше.',
          );
          await LogService.log(
              'Gallery upload blocked by limit for master $_masterId. Status: $status, response: $res');
          break;
        }
        final isError = responseData['error'] == true || res['error'] == true || status >= 400;
        final message = (messageRaw ?? '').toString().toLowerCase();
        if (isError || message != 'uploaded') {
          await LogService.log(
              'Gallery upload failed for master $_masterId. Status: $status, response: $res');
          AppToast.show('Помилка завантаження фото', background: Colors.red);
          break;
        }
        sent += chunk.length;
        if (mounted) setState(() => _uploadProgress = sent / payload.length);
      }

      allUploaded = sent == payload.length && payload.isNotEmpty;
      if (allUploaded) {
        // Refresh details only if everything really uploaded
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0.0;
        });
        if (allUploaded) {
          AppToast.show('Фото завантажено', background: Colors.green);
        }
      }
    }
  }

  Future<void> _showUpgradeDialog({required String title, required String message}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Styles().primaryColor,
        title: Text(title, style: TextStyle(color: Styles().titleColor)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Закрити', style: TextStyle(color: Styles().titleColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumPage()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Styles().checkColor, elevation: 0),
            child: Text('Оформити Premium', style: TextStyle(color: Styles().titleColor)),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensurePhotosPermission() async {
    // On Android 13+ (API 33+), ImagePicker uses Photo Picker which doesn't require permissions
    // On iOS and older Android, we check permissions
    if (Platform.isAndroid) {
      // On Android 13+, ImagePicker handles permissions automatically via Photo Picker
      // We don't need to request permissions explicitly
      return true;
    }
    
    // iOS: Permission.photos
    var status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    await _showPermissionModal(
      title: 'Немає доступу до фото',
      message:
          'Надайте доступ до ваших фото, щоб додати аватар і галерею.',
    );
    return false;
  }

  Future<void> _showPermissionModal({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Styles().primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, color: Styles().titleColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Styles().titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _ensurePhotosPermission();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles().checkColor,
                    elevation: 0,
                  ),
                  child: Text('Надати доступ',
                      style: TextStyle(color: Styles().titleColor)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAdditionalServicesDialog() async {
    final serviceProv = Provider.of<ServiceProvider>(context, listen: false);
    final items = serviceProv.services;
    final Set<int> draft = Set<int>.from(_additionalServiceIds);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSB) {
            return Theme(
              data: Theme.of(context).copyWith(
                checkboxTheme: CheckboxThemeData(
                  fillColor: MaterialStateProperty.all(Styles().primaryColor),
                  checkColor: MaterialStateProperty.all(Styles().titleColor),
                  side: BorderSide(color: Styles().primaryColor.withOpacity(0.4), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                unselectedWidgetColor: Styles().titleColor,
              ),
              child: AlertDialog(
                backgroundColor: Styles().primaryColor,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Додаткові послуги', style: TextStyle(color: Styles().titleColor)),
                    const SizedBox(height: 6),
                    Builder(builder: (_) {
                      final mainId = _selectedService?.id;
                      final currentTotal = (mainId != null ? 1 : 0) + draft.length;
                      final remaining = _maxServices - currentTotal;
                      return Text(
                        'Ви можете вибрати ще ${remaining < 0 ? 0 : remaining} послуг',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      );
                    }),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final svc = items[i];
                      final checked = draft.contains(svc.id);
                      return Container(
                        decoration: BoxDecoration(
                          color: Styles().backgroundFormColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            if (v == true) {
                              final mainId = _selectedService?.id;
                              final currentTotal = (mainId != null ? 1 : 0) + draft.length;
                              if (currentTotal + 1 > _maxServices) {
                                AppToast.show('Досягнуто ліміту послуг. Оновіть до Premium.', background: Colors.red);
                                return;
                              }
                              draft.add(svc.id);
                            } else {
                              draft.remove(svc.id);
                            }
                            setSB(() {});
                          },
                          title: Text(svc.name, style: TextStyle(color: Styles().titleColor)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Скасувати', style: TextStyle(color: Styles().titleColor)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Styles().primaryColor, elevation: 0),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _saveAdditionalServices(draft);
                    },
                    child: Text('Зберегти', style: TextStyle(color: Styles().titleColor)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAdditionalServices(Set<int> draft) async {
    // Ensure main service is present
    final mainId = _selectedService?.id;
    if (mainId != null) draft.add(mainId);

    final api = ApiService(AppConstants.serverUrl);
    final res = await api.putRequest('masters/$_masterId/services', {
      'service_ids': draft.toList(),
    });
    if ((res['status']?.toString().toLowerCase() ?? '') == 'ok') {
      setState(() {
        _additionalServiceIds = draft;
      });
      AppToast.show('Послуги оновлено', background: Colors.green);
    } else {
      final status = (res['status'] is num) ? (res['status'] as num).toInt() : 400;
      if (status == 403 && (res['upgrade_required'] == true || res['limit'] != null)) {
        await _showUpgradeDialog(
          title: 'Досягнуто ліміту послуг',
          message: 'Ви можете обрати не більше $_maxServices послуг. Оновіть до Premium для розширення.',
        );
      } else {
        AppToast.show('Не вдалося оновити послуги', background: Colors.red);
      }
    }
  }

  Widget _buildGalleryGrid() {
    // Build combined list: main photo first (non-deletable), then gallery items
    final List<Map<String, dynamic>> items = [];
    if (_mainPhotoPath.isNotEmpty) {
      items.add({'id': null, 'url': _mainPhotoPath});
    }
    items.addAll(_gallery);

    if (_loadingDetails && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('Немає фото', style: const TextStyle(color: Styles.descriptionColor)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final it = items[index];
        final String url = _buildUrl(it['url'] as String);
        final int? photoId = it['id'] as int?;
        final bool deletable = photoId != null;
        return GestureDetector(
          onTap: () => _openGalleryViewer(items, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(url, fit: BoxFit.cover),
                if (deletable)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () async {
                        await _deletePhoto(photoId);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.delete, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePhoto(int photoId) async {
    final api = ApiService(AppConstants.serverUrl);
    final res = await api.deleteRequest('masters/$_masterId/gallery/$photoId');
    if ((res['status']?.toString().toLowerCase() ?? '') == 'ok') {
      setState(() {
        _gallery.removeWhere((g) => (g['id'] as int) == photoId);
      });
      AppToast.show('Фото видалено', background: Colors.green);
    } else {
      AppToast.show('Не вдалося видалити фото', background: Colors.red);
    }
  }

  Future<void> _openGalleryViewer(List<Map<String, dynamic>> items, int initialIndex) async {
    final urls = items.map((e) => _buildUrl(e['url'] as String)).toList();
    int current = initialIndex;
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          return GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: PageController(initialPage: current),
                    itemCount: urls.length,
                    onPageChanged: (i) => setDlg(() => current = i),
                    itemBuilder: (c, i) => InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(urls[i], fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(urls.length, (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == current ? Colors.white : Colors.white38,
                        ),
                      )),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
      // Refresh local user data after successful update
      final api = ApiService(AppConstants.serverUrl);
      final meResponse = await api.getRequest('auth/me');
      final userJson = meResponse.containsKey('user') ? meResponse['user'] : meResponse;
      final user = User.fromJson(userJson as Map<String, dynamic>);
      await UserService().saveUserData(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } else {
      // Handle validation errors
      String errorMessage = 'Error';
      final status = (res['status'] is num) ? (res['status'] as num).toInt() : 400;
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
      if (status == 422 && (res['limit'] != null)) {
        await _showUpgradeDialog(
          title: 'Опис занадто довгий',
          message: 'Опис занадто довгий. Підключіть Premium, щоб збільшити ліміт.',
        );
        return;
      }
      AppToast.show(errorMessage, background: Colors.red);
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService().logout();
    } catch (_) {}
    try {
      await TokenService().deleteTokens();
    } catch (_) {}
    try {
      await UserService().deleteUser();
    } catch (_) {}
    if (mounted) {
      AppToast.show('Ви вийшли з акаунту', background: Colors.green);
      Navigator.pop(context);
    }
  }
} 