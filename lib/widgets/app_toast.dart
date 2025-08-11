import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AppToast {
  AppToast._();

  static void show(String message,
      {Color background = const Color(0xFF323232),
      Color textColor = Colors.white,
      Duration duration = const Duration(seconds: 2)}) {
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: background,
      textColor: textColor,
      toastLength: Toast.LENGTH_SHORT,
      fontSize: 15,
      timeInSecForIosWeb: duration.inSeconds,
    );
  }
} 