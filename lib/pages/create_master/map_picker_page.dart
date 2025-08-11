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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    await _requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _mapController.move(_currentLocation!, 18); // Оновити позицію мапи
      _selectedLocation =
          _currentLocation; // Встановити початкове місце маркера
    });
  }

  Future<void> _requestPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
  }

  void _updateSelectedLocation() {
    setState(() {
      _selectedLocation = _mapController.camera.center;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Stack(
        children: [
        
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ??
                  const LatLng(37.7749, -122.4194), // Default to San Francisco
              initialZoom: 25,
              onPositionChanged: (MapCamera mapCamera, bool hasGesture) {
                if (hasGesture) {
                  _updateSelectedLocation(); // Оновити вибрану локацію при русі карти
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}{r}.png',
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
                Navigator.pushNamed(
                  context,
                  '/create-master',
                  arguments: _selectedLocation,
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
