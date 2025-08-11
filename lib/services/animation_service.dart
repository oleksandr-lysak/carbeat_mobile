import 'package:flutter/animation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AnimationService {
  static void animatedMapMove(
      MapController mapController,
      AnimationController animationController,
      LatLng destLocation,
      double destZoom) {
    final latTween = Tween<double>(
        begin: mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween =
        Tween<double>(begin: mapController.camera.zoom, end: destZoom);

    animationController.addListener(() {
      mapController.move(
          LatLng(latTween.evaluate(animationController),
              lngTween.evaluate(animationController)),
          zoomTween.evaluate(animationController),
          offset: const Offset(0, 0));
    });

    animationController.forward(from: 0);
  }
}
