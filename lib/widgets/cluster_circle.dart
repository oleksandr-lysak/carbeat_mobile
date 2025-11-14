import 'package:flutter/material.dart';
import 'package:carbeat/classes/garage_marker.dart';
import 'package:carbeat/constants/styles.dart';

/// Circle icon for map clusters with optional bounce animation if any master is available.
class ClusterCircle extends StatefulWidget {
  final List<GarageMarker> markers;
  const ClusterCircle({super.key, required this.markers});
  
  @override
  State<ClusterCircle> createState() => _ClusterCircleState();
}

class _ClusterCircleState extends State<ClusterCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant ClusterCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configureAnimation();
  }

  void _configureAnimation() {
    final bool hasAvailable = widget.markers.any((m) => m.master.available);
    _controller.stop();
    if (hasAvailable) {
      _bounceAnimation = Tween<double>(begin: 0.0, end: -8.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.bounceInOut),
      );
      _controller.repeat(reverse: true);
    } else {
      _bounceAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.linear),
      );
      _controller.reset();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final int count = widget.markers.length;
    final bool hasPremium = widget.markers.any((m) => m.master.isPremium == true);
  
    final Color baseGreen = Styles().primaryColor;
  
    double size;
    if (count < 10) {
      size = 52;
    } else if (count < 100) {
      size = 60;
    } else if (count < 1000) {
      size = 72;
    } else if (count < 10000) {
      size = 88;
    } else {
      size = 104;
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 28,
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

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: base,
        );
      },
    );
  }
} 