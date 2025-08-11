import 'package:carbeat/models/master.dart';
import 'package:flutter_map/flutter_map.dart';

class GarageMarker extends Marker {
  final Master master;

  const GarageMarker({
    required super.key,
    required super.point,
    required super.child,
    required this.master,
    super.width = 40.0,
    super.height = 40.0,
  });
}
