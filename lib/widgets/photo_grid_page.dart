import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:latlong2/latlong.dart' as latlong;

class PhotoGridPage extends StatefulWidget {
  const PhotoGridPage({super.key});

  @override
  State<PhotoGridPage> createState() => _PhotoGridPageState();
}

class _PhotoGridPageState extends State<PhotoGridPage> {
  final ImagePicker _picker = ImagePicker();
  List<AssetEntity> _photos = [];
  AssetEntity? _selectedPhoto;
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
    final PermissionState permitted =
        await PhotoManager.requestPermissionExtend();
    if (permitted.hasAccess) {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      final List<AssetEntity> photos = await albums.first.getAssetListPaged(
        page: 0,
        size: 50,
      );
      setState(() {
        _photos = photos;
      });
    } else {
      // Обробка випадку, коли немає дозволу на доступ до галереї
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

    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, 'choose_photo')),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          if (_selectedPhoto != null)
            IconButton(
              icon: const Icon(Icons.navigate_next, color: Colors.black),
              onPressed: () {
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
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4.0,
            mainAxisSpacing: 4.0,
          ),
          itemCount: _photos.length + 1, // +1 для іконки камери
          itemBuilder: (context, index) {
            if (index == 0) {
              return GestureDetector(
                onTap: _pickCameraImage,
                child: Container(
                  color: Theme.of(context).hoverColor,
                  child: Icon(Icons.camera_alt,
                      size: 50, color: Theme.of(context).primaryColor),
                ),
              );
            } else {
              final photo = _photos[index - 1];
              return GestureDetector(
                onTap: () => _onPhotoTapped(photo),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(8.0), // Додає округлені кути
                      child: FutureBuilder<File?>(
                        future: photo.file,
                        builder: (context, snapshot) {
                          final file = snapshot.data;
                          if (file == null) return const SizedBox();
                          return Image.file(
                            file,
                            fit: BoxFit
                                .cover, // Зміна BoxFit для кращого відображення
                            width: double.infinity,
                            height: double.infinity,
                          );
                        },
                      ),
                    ),
                    if (_selectedPhoto == photo)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          color: Colors.black54,
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24.0, // Розмір галочки
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
