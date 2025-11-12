import 'dart:io';
import 'dart:typed_data';
import 'package:carbeat/services/log_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:carbeat/constants/styles.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoGridPage extends StatefulWidget {
  const PhotoGridPage({super.key});

  @override
  State<PhotoGridPage> createState() => _PhotoGridPageState();
}

class _PhotoGridPageState extends State<PhotoGridPage> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  List<AssetEntity> _photos = [];
  String? _selectedPhotoId;
  bool _permissionGranted = true;
  late latlong.LatLng? _selectedLocation;
  late String? _phone;
  late String? _name;
  late String? _description;
  late int? _specialtyId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadGalleryImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // After permission dialogs or returning from Settings, refresh gallery
      _loadGalleryImages();
    }
  }

  Future<void> _loadGalleryImages() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      // Єдиний офіційний запит доступу до фото
      final perm = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(),
      );
      if (!perm.hasAccess) {
        setState(() {
          _permissionGranted = false;
          _photos = [];
        });
        // Пояснювальне модальне вікно з неможливістю пропустити (без переходу в налаштування)
        await _showBlockingPermissionModal(
          title: 'Немає доступу до галереї',
          message:
              'Нам потрібен доступ до ваших фото, щоб додати зображення профілю. '
              'Натисніть “Надати доступ”, щоб продовжити.',
          onRetry: () async {
            final again = await PhotoManager.requestPermissionExtend(
              requestOption: const PermissionRequestOption(),
            );
            if (again.hasAccess) {
              await _loadGalleryImages();
            } else {
              // Залишимо на екрані прохання про дозвіл
              if (mounted) {
                setState(() {
                  _permissionGranted = false;
                  _photos = [];
                });
              }
            }
          },
        );
        _isLoading = false;
        return;
      }

      // Спробувати єдиний альбом "All" без дублікатів; fallback на всі альбоми з дедупом
      final List<AssetPathEntity> allAlbumList = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );

      List<AssetEntity> collected = [];
      if (allAlbumList.isNotEmpty) {
        collected = await allAlbumList.first.getAssetListPaged(page: 0, size: 100);
      } else {
        final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
          type: RequestType.image,
          onlyAll: false,
        );
        final Map<String, AssetEntity> byId = {};
        for (final album in albums) {
          final items = await album.getAssetListPaged(page: 0, size: 100);
          for (final it in items) {
            if (!byId.containsKey(it.id)) {
              byId[it.id] = it;
              if (byId.length >= 100) break;
            }
          }
          if (byId.length >= 100) break;
        }
        collected = byId.values.toList();
      }
      collected.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

      setState(() {
        _photos = collected.take(50).toList();
        _permissionGranted = true;
      });
    } catch (e) {
      LogService.log('Error loading gallery images: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _pickCameraImage() async {
    // Запит камери окремо та дружнє блокуюче вікно при відмові
    if (!await _ensureCameraPermission()) {
      return;
    }
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final asset = await _saveImageToGallery(file);
      if (asset != null) {
        setState(() {
          // Remove duplicates of the same asset id, then insert newest at top
          _photos.removeWhere((p) => p.id == asset.id);
          _photos.insert(0, asset);
          _selectedPhotoId = asset.id;
        });
      }
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    if (status.isGranted) return true;
    // Якщо користувач відмовив — пояснити і дати кнопку “Надати доступ” (без переходу в налаштування)
    await _showBlockingPermissionModal(
      title: 'Немає доступу до камери',
      message:
          'Нам потрібен доступ до камери, щоб зробити фото. '
          'Натисніть “Надати доступ”, щоб продовжити.',
      onRetry: () async {
        await Permission.camera.request();
      },
    );
    return false;
  }

  Future<void> _showBlockingPermissionModal({
    required String title,
    required String message,
    required Future<void> Function() onRetry,
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
                    await onRetry();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles().checkColor,
                    elevation: 0,
                  ),
                  child: Text(
                    'Надати доступ',
                    style: TextStyle(color: Styles().titleColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<AssetEntity?> _saveImageToGallery(File file) async {
    final bytes = await file.readAsBytes();
    final result = await PhotoManager.editor
        .saveImage(bytes, title: 'photo1', filename: 'photo1');
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      final List<AssetEntity> photos = await albums.first.getAssetListPaged(
        page: 0,
        size: 50,
      );
      try {
        return photos.firstWhere((photo) => photo.id == result.id);
      } catch (e) {
        return null;
      }
  }

  void _onPhotoTapped(AssetEntity photo) {
    setState(() {
      if (_selectedPhotoId == photo.id) {
        _selectedPhotoId = null;
      } else {
        _selectedPhotoId = photo.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _selectedLocation =
        (ModalRoute.of(context)?.settings.arguments as List<dynamic>? ?? [])[0]
            as latlong.LatLng?;
    _phone = (ModalRoute.of(context)?.settings.arguments as List<dynamic>? ??
        [])[1] as String?;
    _name = (ModalRoute.of(context)?.settings.arguments as List<dynamic>? ??
        [])[2] as String?;
    _description =
        (ModalRoute.of(context)?.settings.arguments as List<dynamic>? ?? [])[3]
            as String?;
    _specialtyId =
        (ModalRoute.of(context)?.settings.arguments as List<dynamic>? ?? [])[4]
            as int?;

    return Stack(children: [
      Scaffold(
        backgroundColor: Styles().primaryColor,
        appBar: AppBar
        (
          title: Text(
            FlutterI18n.translate(context, 'choose_photo'),
            style: TextStyle(color: Styles().titleColor),
          ),
          backgroundColor: Styles().primaryColor,
          iconTheme: IconThemeData(color: Styles().titleColor),
          actionsIconTheme: IconThemeData(color: Styles().titleColor),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _permissionGranted && _photos.isNotEmpty
              ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: _photos.length + 1, // +1 для іконки камери
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _pickCameraImage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Styles().backgroundFormColor,
                      borderRadius: BorderRadius.circular(Styles.borderRadius),
                    ),
                    child: Center(
                      child: Icon(Icons.camera_alt,
                          size: 40, color: Styles().primaryColor),
                    ),
                  ),
                );
              } else {
                final photo = _photos[index - 1];
                final bool isSelected = _selectedPhotoId == photo.id;
                return GestureDetector(
                  onTap: () => _onPhotoTapped(photo),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(Styles.borderRadius),
                          border: isSelected
                              ? Border.all(color: Styles.selectedBorder, width: 2)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(Styles.borderRadius),
                          child: FutureBuilder<Uint8List?>(
                            future: photo.thumbnailDataWithSize(const ThumbnailSize.square(300)),
                            builder: (context, snapshot) {
                              final bytes = snapshot.data;
                              if (bytes == null) {
                                return const SizedBox();
                              }
                              return Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              );
                            },
                          ),
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: Styles.selectedColor.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Styles().titleColor,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
            },
          )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 48, color: Styles().titleColor.withOpacity(0.7)),
                      const SizedBox(height: 12),
                      Text(
                        _permissionGranted
                            ? FlutterI18n.translate(context, 'gallery.no_photos')
                            : FlutterI18n.translate(context, 'gallery.permission_needed'),
                        style: TextStyle(color: Styles().titleColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadGalleryImages,
                        style: ElevatedButton.styleFrom(backgroundColor: Styles().checkColor),
                        child: Text(
                          FlutterI18n.translate(context, 'gallery.retry'),
                          style: TextStyle(color: Styles().titleColor),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
      Positioned(
        left: MediaQuery.of(context).size.width * 0.3,
        right: MediaQuery.of(context).size.width * 0.3,
        bottom: MediaQuery.of(context).size.height * 0.02,
        child: ElevatedButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Styles().checkColor),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
            ),
          ),
          onPressed: () {
            if (_selectedPhotoId == null) return;
            Navigator.pushNamed(
              context,
              '/summary-info',
              arguments: [
                _selectedLocation,
                _phone,
                _name,
                _description,
                _specialtyId,
                _selectedPhotoId,
              ],
            );
          },
          child: Text(
            '${FlutterI18n.translate(context, 'next')} ...',
            style: TextStyle(color: Styles().titleColor, fontSize: 24),
          ),
        ),
      ),
    ],);
  }
}
