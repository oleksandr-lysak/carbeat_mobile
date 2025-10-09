import 'package:flutter/material.dart';
import 'package:carbeat/classes/garage_marker.dart';
import 'package:carbeat/constants/styles.dart';

/// Circle icon for map clusters (stateless & lightweight).
/// Shows number of markers inside and optional star overlay if any premium master exists.
class ClusterCircle extends StatelessWidget {
  final List<GarageMarker> markers;
  const ClusterCircle({super.key, required this.markers});

  @override
  Widget build(BuildContext context) {
    final int count = markers.length;
    final bool hasPremium = markers.any((m) => m.master.tariffId == 2);

    final Color baseGreen = Styles().primaryColor;

    // Dynamically scale cluster size to ensure multi-digit labels fit (up to 5+ digits)
    double size;
    if (count < 10) {
      size = 52;
    } else if (count < 100) {
      size = 60;
    } else if (count < 1000) {
      size = 72;
    } else if (count < 10000) {
      size = 88; // 4 digits
    } else {
      size = 104; // 5+ digits
    }

    Widget base = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [baseGreen, baseGreen.withOpacity(0.0)],
          stops: const [0.4, 1.0],
        ),
      ),
      child: const SizedBox.shrink(),
    );

    base = Stack(
      alignment: Alignment.center,
      children: [
        base,
        Center(
          // FittedBox ensures the text scales to fit the available circle size
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 28, // base; will be scaled down by FittedBox as needed
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
            ),
          ),
        ),
      ],
    );

    if (hasPremium) {
      base = Stack(
        clipBehavior: Clip.none,
        children: const [
          // base will be inserted by parent Stack in build above
        ],
      );
      base = Stack(
        clipBehavior: Clip.none,
        children: [
          base,
          Positioned(
            top: -6,
            right: -6,
            child: Icon(
              Icons.star,
              color: const Color(0xFFFFD700),
              size: (size * 0.28).clamp(18.0, 26.0),
            ),
          ),
        ],
      );
    }

    return base;
  }
} 