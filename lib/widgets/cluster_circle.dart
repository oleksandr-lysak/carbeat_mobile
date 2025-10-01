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

    double size;
    double fontSize;
    if (count < 10) {
      size = 60;
      fontSize = 18;
    } else if (count < 100) {
      size = 75;
      fontSize = 20;
    } else {
      size = 90;
      fontSize = 22;
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
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
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
          const Positioned(
            top: -6,
            right: -6,
            child: Icon(Icons.star, color: Color(0xFFFFD700), size: 24),
          ),
        ],
      );
    }

    return base;
  }
} 