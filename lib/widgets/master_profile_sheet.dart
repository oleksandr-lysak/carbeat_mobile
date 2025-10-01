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
  bool _loadingDetails = true;
  late int _masterId;

  // Details
  List<Map<String, dynamic>> _gallery = [];
  List<Map<String, dynamic>> _reviews = [];
  Set<int> _additionalServiceIds = {};
  String _mainPhotoPath = '';
  bool _uploading = false;
  double _uploadProgress = 0.0;

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
                            : (_mainPhotoPath.isNotEmpty
                                ? NetworkImage(_buildUrl(_mainPhotoPath))
                                : null) as ImageProvider<Object>?,
                        child: _avatarBase64 == null && _mainPhotoPath.isEmpty
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
                              backgroundColor: Styles().backgroundFormColor,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _openAdditionalServicesDialog,
                            child: Text(
                              'Додаткові послуги',
                              style: TextStyle(
                                color: Styles().primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Styles().backgroundFormColor,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _addGalleryPhotos,
                            child: Text(
                              'Додати фото',
                              style: TextStyle(
                                color: Styles().primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
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
                          color: Styles().checkColor,
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

  String _buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConstants.publicServerUrl.endsWith('/')
        ? AppConstants.publicServerUrl.substring(0, AppConstants.publicServerUrl.length - 1)
        : AppConstants.publicServerUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
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

  Future<void> _addGalleryPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 100);
    if (picked.isEmpty) return;

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
    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });
    while (sent < payload.length) {
      final chunk = payload.sublist(sent, (sent + 10) > payload.length ? payload.length : sent + 10);
      final res = await api.postRequest('masters/$_masterId/gallery', {
        'photos': chunk,
      });
      if (res['message']?.toString().toLowerCase() != 'uploaded') {
        AppToast.show('Помилка завантаження фото', background: Colors.red);
        break;
      }
      sent += chunk.length;
      if (mounted) setState(() => _uploadProgress = sent / payload.length);
    }

    // Refresh details
    await _load();
    if (mounted) {
      setState(() {
        _uploading = false;
        _uploadProgress = 0.0;
      });
      AppToast.show('Фото завантажено', background: Colors.green);
    }
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
            return AlertDialog(
              backgroundColor: Styles().primaryColor,
              title: Text('Додаткові послуги', style: TextStyle(color: Styles().titleColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final svc = items[i];
                    final checked = draft.contains(svc.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (v) {
                        if (v == true) {
                          draft.add(svc.id);
                        } else {
                          draft.remove(svc.id);
                        }
                        setSB(() {});
                      },
                      title: Text(svc.name, style: TextStyle(color: Styles().titleColor)),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Styles().checkColor,
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
                  style: ElevatedButton.styleFrom(backgroundColor: Styles().checkColor),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _saveAdditionalServices(draft);
                  },
                  child: Text('Зберегти', style: TextStyle(color: Styles().titleColor)),
                ),
              ],
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
      AppToast.show('Не вдалося оновити послуги', background: Colors.red);
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
                        await _deletePhoto(photoId!);
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