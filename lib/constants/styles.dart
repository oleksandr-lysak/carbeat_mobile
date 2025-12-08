import 'package:flutter/material.dart';
import 'package:carbeat/config/flavor_config.dart';

class Styles {
  AppFlavor get _flavor => FlavorConfig.current.flavor;

  // Background color
  Color get backgroundColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color.fromARGB(255, 33, 32, 32);
      case AppFlavor.floxcity:
        return const Color.fromARGB(255, 33, 32, 32);
    }
  }

  // Primary color (зелений)
  Color get primaryColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color.fromARGB(255, 61, 140, 214);
      case AppFlavor.floxcity:
        return const Color(0xFF27AE60); // Emerald green
    }
  }

  // Title color
  Color get titleColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return Colors.white;
      case AppFlavor.floxcity:
        return Colors.white;
    }
  }

  static const Color subtitleColor = Colors.white70;
  static const Color descriptionColor = Colors.white70;

  // Background form color (пастельний зелений)
  Color get backgroundFormColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color.fromARGB(255, 202, 231, 250);
      case AppFlavor.floxcity:
        return const Color(0xFFE8F8F5); // Light mint green
    }
  }

  static const Color textInputColor = Color.fromARGB(250, 110, 110, 110);

  // Selected color (трохи темніший зелений)
  Color get selectedColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xff3d8cd6);
      case AppFlavor.floxcity:
        return const Color(0xFF27AE60); // consistent with primary
    }
  }

  static const Color selectedBorder = Colors.black87;

  // Check color (темно-зелений)
  Color get checkColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color.fromARGB(255, 33, 65, 95);
      case AppFlavor.floxcity:
        return const Color(0xFF145A32); // dark green
    }
  }

  static const double borderRadius = 20.0;

  // Premium color
  Color get premiumColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFFFFD700);
      case AppFlavor.floxcity:
        return const Color(0xFFFFD700);
    }
  }

  // Available color
  Color get availableColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFF00C853);
      case AppFlavor.floxcity:
        return const Color(0xFF00C853); // ok
    }
  }

  Color get unavailableColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFFBDBDBD);
      case AppFlavor.floxcity:
        return const Color(0xFFBDBDBD);
    }
  }

  // Active marker (зелений акцент як blueAccent)
  Color get activeMarkerColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return Colors.blueAccent;
      case AppFlavor.floxcity:
        return const Color(0xFF00E676); // vivid green accent
    }
  }

  Color get darkBackgroundColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFF121212);
      case AppFlavor.floxcity:
        return const Color(0xFF121212);
    }
  }

  Color get darkAppBarBackground {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFF333333);
      case AppFlavor.floxcity:
        return const Color(0xFF333333);
    }
  }

  Color get lightAppBarBackground {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFFDDDDDD);
      case AppFlavor.floxcity:
        return const Color(0xFFDDDDDD);
    }
  }

  Color get darkInputFillColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color(0xFF424242);
      case AppFlavor.floxcity:
        return const Color(0xFF424242);
    }
  }

  Color get lightInputFillColor {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return const Color.fromARGB(255, 235, 234, 234);
      case AppFlavor.floxcity:
        return const Color.fromARGB(255, 235, 234, 234);
    }
  }

  // App icon path
  String get appIconPath {
    switch (_flavor) {
      case AppFlavor.carbeat:
        return 'assets/icons/app/carbeat.png';
      case AppFlavor.floxcity:
        return 'assets/icons/app/floxcity.png';
    }
  }
}
