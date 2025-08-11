import 'package:flutter/material.dart';
//import 'package:flutter_svg/flutter_svg.dart';
//import 'package:provider/provider.dart';

//import '../classes/app_themes.dart';
//import '../providers/theme_provider.dart';

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  LoadingState createState() => LoadingState();
}

class LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // ignore: unused_field
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1), // Тривалість повного циклу
      vsync: this,
    )..repeat(reverse: true);

    // Анімація обертання з періодичним загальмовуванням
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut, // Зміна швидкості обертання
      ),
    );

    // Анімація зміни масштабу
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut, // Розширення і стиснення з гальмуванням
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String iconPath = 'assets/icons/app/garage_go.png';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
            scale: _scaleAnimation.value,
            child: Image.asset(
              iconPath,
              height: 70,
              width: 70,
            ),
          
        );
      },
    );
  }
}
