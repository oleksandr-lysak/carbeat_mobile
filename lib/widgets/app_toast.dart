import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../constants/styles.dart';

class AppToast {
  AppToast._();

  static void show(String message,
      {Color? background,
      Color? textColor,
      Duration duration = const Duration(seconds: 2)}) {
    final styles = Styles();
    final bgColor = background ?? styles.backgroundColor;
    final txtColor = textColor ?? styles.titleColor;
    Fluttertoast.showToast(
      msg: message,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: bgColor,
      textColor: txtColor,
      toastLength: Toast.LENGTH_SHORT,
      fontSize: 15,
      timeInSecForIosWeb: duration.inSeconds,
    );
  }
} 