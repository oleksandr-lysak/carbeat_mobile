import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:carbeat/classes/garage_marker.dart';

class PulsatingIcon extends StatefulWidget {
  final List<GarageMarker> markers;

  const PulsatingIcon({super.key, required this.markers});

  @override
  PulsatingIconState createState() => PulsatingIconState();
}

class PulsatingIconState extends State<PulsatingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    bool available = false;
    for (GarageMarker marker in widget.markers) {
      if (marker.master.available) {
        available = true;
        break;
      }
    }
    if (available) {
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    } else {
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SvgPicture.asset(
            'assets/icons/cluster_light.svg',
            height: 100,
            width: 100,
          ),
        );
      },
    );
  }
}
