import 'dart:io';
import 'dart:typed_data';
import 'package:carbeat/services/log_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:carbeat/constants/styles.dart';

class PhotoGridPage extends StatefulWidget {
  const PhotoGridPage({super.key});

  @override
  State<PhotoGridPage> createState() => _PhotoGridPageState();
}

class _PhotoGridPageState extends State<PhotoGridPage> {
  final ImagePicker _picker = ImagePicker();
  List<AssetEntity> _photos = [];
  AssetEntity? _selectedPhoto;
  bool _permissionGranted = true;
  late latlong.LatLng? _selectedLocation;
  late String? _phone;
  late String? _name;
  late String? _description;
  late int? _specialtyId;

  @override
  void initState() {
    super.initState();
    _loadGalleryImages();
  }

  Future<void> _loadGalleryImages() async {
    try {
      // 1) Перевіряємо поточний стан
      PermissionState state = await PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(),
      );
      if (!state.hasAccess) {
        // 2) Запитуємо дозвіл
        state = await PhotoManager.requestPermissionExtend(
          requestOption: const PermissionRequestOption(),
        );
      }

      // 3) Повторна перевірка після запиту (деякі пристрої повертають стан не одразу)
      state = await PhotoManager.getPermissionState(
        requestOption: const PermissionRequestOption(),
      );
      if (!state.hasAccess) {
        setState(() {
          _permissionGranted = false;
          _photos = [];
        });
        return;
      }

      // Завантажуємо з усіх альбомів, а не лише "All", бо на деяких пристроях він може бути порожнім
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );

      final List<AssetEntity> collected = [];
      for (final album in albums) {
        final items = await album.getAssetListPaged(page: 0, size: 50);
        collected.addAll(items);
        if (collected.length >= 50) break;
      }

      // Сортуємо за датою створення (новіші спочатку)
      collected.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

      setState(() {
        _photos = collected.take(50).toList();
        _permissionGranted = true;
      });
    } catch (e) {
      LogService.log('Error loading gallery images: $e');
    }
  }

  Future<void> _pickCameraImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final asset = await _saveImageToGallery(file);
      if (asset != null) {
        setState(() {
          _photos.insert(0, asset);
        });
      }
    }
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
      if (_selectedPhoto == photo) {
        _selectedPhoto =
            null;
      } else {
        _selectedPhoto = photo;
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
                final bool isSelected = _selectedPhoto == photo;
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              await PhotoManager.openSetting();
                            },
                            child: Text(FlutterI18n.translate(context, 'gallery.open_settings')),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _loadGalleryImages,
                            style: ElevatedButton.styleFrom(backgroundColor: Styles().checkColor),
                            child: Text(FlutterI18n.translate(context, 'gallery.retry'), style: TextStyle(color: Styles().titleColor)),
                          ),
                        ],
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
            if (_selectedPhoto == null) return;
            Navigator.pushNamed(
              context,
              '/summary-info',
              arguments: [
                _selectedLocation,
                _phone,
                _name,
                _description,
                _specialtyId,
                _selectedPhoto?.id,
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
