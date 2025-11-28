import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:carbeat/constants/styles.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  MapPickerPageState createState() => MapPickerPageState();
}

class MapPickerPageState extends State<MapPickerPage> {
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  String? _phone;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    await _requestPermission();
    try {
      // 1) Швидкий старт з останньої відомої позиції (може бути null)
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        _currentLocation = LatLng(last.latitude, last.longitude);
        _mapController.move(_currentLocation!, 18);
        _selectedLocation = _currentLocation;
        setState(() {});
      }
      // 2) Точна поточна позиція з таймаутом
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _mapController.move(_currentLocation!, 18);
        _selectedLocation = _currentLocation;
      });
    } catch (_) {
      // Ігноруємо – залишимо дефолтний центр; користувач може посунути карту вручну
    }
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    // Якщо deniedForever – не блокуємо UI, просто не зрушуємо камеру
  }

  void _updateSelectedLocation() {
    setState(() {
      _selectedLocation = _mapController.camera.center;
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _phone == null) {
      final dynamic phoneArg = args['phone'];
      if (phoneArg is String) {
        _phone = phoneArg;
      }
    }
    return Scaffold(
      backgroundColor: Styles().titleColor,
      body: Stack(
        children: [
        
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              minZoom: 2,
              maxZoom: 18,
              initialCenter: _currentLocation ?? const LatLng(50.4501, 30.5234),
              initialZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (MapCamera mapCamera, bool hasGesture) {
                if (hasGesture) {
                  _updateSelectedLocation(); // Оновити вибрану локацію при русі карти
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'com.it-pragmat.plant',
                tileProvider: const FMTCStore('mapStore').getTileProvider(),
              ),
            ],
          ),
          Center(
            child: Icon(Icons.location_on,
                color: Styles().primaryColor, size: 40.0),
          ),
          Positioned(
            left: MediaQuery.of(context).size.width * 0.3,
            right: MediaQuery.of(context).size.width * 0.3,
            bottom: MediaQuery.of(context).size.height * 0.02,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Styles().primaryColor),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
              onPressed: () {
                if (_selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        FlutterI18n.translate(
                          context,
                          'select_location',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pushNamed(
                  context,
                  '/create-master',
                  arguments: {
                    'location': _selectedLocation,
                    'phone': _phone,
                  },
                );
              },
              child: Text(
                '${FlutterI18n.translate(context, 'next')} ...',
                style: TextStyle(color: Styles().titleColor, fontSize: 24),
              ),
            ),
          ),
          Positioned(
            left: MediaQuery.of(context).size.width * 0.1,
            right: MediaQuery.of(context).size.width * 0.1,
            top: MediaQuery.of(context).size.height * 0.05,
            child: Container(
              padding: const EdgeInsets.all(10.0),
            
              child: Row(
                children: [
                  BackButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(width: 10),
                  Text(FlutterI18n.translate(context, 'select_location'),
                      style: const TextStyle(fontSize: 26, color: Colors.black)),
                  
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
