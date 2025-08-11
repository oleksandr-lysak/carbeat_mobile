import 'package:flutter/material.dart';
import 'package:carbeat/classes/garage_marker.dart';
import 'package:carbeat/constants/styles.dart';

/// Circle icon for map clusters.
///
/// - Shows number of markers inside.
/// - Pulsates when at least one available master present.
/// - Adds gold star overlay when at least one premium (tariffId==2) master present.
class ClusterCircle extends StatefulWidget {
  final List<GarageMarker> markers;
  const ClusterCircle({super.key, required this.markers});

  @override
  State<ClusterCircle> createState() => _ClusterCircleState();
}

class _ClusterCircleState extends State<ClusterCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final hasAvailable = widget.markers.any((m) => m.master.available);

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (hasAvailable) {
      _scale = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
      _controller.repeat(reverse: true);
    } else {
      _scale = AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.markers.length;
    //final hasPremium = widget.markers.any((m) => m.master.tariffId == 2);

    // Determine colors
    //final outerColor = widget.markers.any((m) => m.master.available) ? const Color(0xFF00C853) : const Color(0xFFBDBDBD);
    //final innerColor = widget.markers.any((m) => m.master.tariffId == 2) ? const Color(0xFFFFD700) : outerColor;

    final Color baseGreen = Styles().primaryColor; // main theme green

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
        // Counter text overlay
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

    if (widget.markers.any((m) => m.master.tariffId == 2)) {
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

    return Transform.scale(scale: _scale.value, child: base);
  }
} 