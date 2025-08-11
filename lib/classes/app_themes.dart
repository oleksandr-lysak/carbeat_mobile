import 'package:flutter/material.dart';

class AppThemes {
  static Color mainColorDark = const Color.fromRGBO(74, 222, 128, 1);
  static Color mainColorLight = const Color.fromARGB(255, 85, 255, 142);
  static final ThemeData darkTheme = ThemeData(
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color.fromRGBO(74, 222, 128, 1),
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
    ),
    brightness: Brightness.dark,
    primaryColor: mainColorDark,
    indicatorColor: const Color.fromRGBO(184, 255, 91, 1),
    scaffoldBackgroundColor: const Color(0xFF121212),
    focusColor: mainColorDark, // Підбираємо для фокусу
    hoverColor: const Color(0xFF424242), // Підбираємо для ховера
    shadowColor: const Color.fromARGB(255, 248, 248, 248).withOpacity(0.2),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF333333), // Темний фон для AppBar
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: TextTheme(
      headlineLarge: const TextStyle(
        color: Colors.white70, // Світлий відтінок для заголовків
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: const TextStyle(
        color: Colors.white60,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: Colors.white60,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: const TextStyle(
        color: Colors.white60,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      bodyLarge: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 18,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: const TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: mainColorDark,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: mainColorDark,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFF424242), // Темний фон для текстових полів
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
        borderSide: BorderSide.none, // Без бордеру
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color:  Color.fromRGBO(74, 222, 128, 1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF64B5F6)),
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: const Color.fromRGBO(184, 255, 91, 1), // Колір кнопок
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(const Color.fromRGBO(74, 222, 128, 1)),
      checkColor: WidgetStateProperty.all(Colors.black),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor:  Color.fromRGBO(74, 222, 128, 1),
      foregroundColor: Colors.black,
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)), // Закруглення кутів
        ),
    ),
  );

  // Темна тема
  static final ThemeData lightTheme = ThemeData(
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8.0)), // Закруглення кутів
        ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor:
          mainColorLight, // Колір фону для світлої теми
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
    ),
    brightness: Brightness.light,
    indicatorColor: Colors.black,
    primaryColor: mainColorLight,
    scaffoldBackgroundColor:
        const Color(0xFFFFFFFF), // Білий фон для світлої теми
    focusColor:
        mainColorLight, // Підбираємо для фокусу
    hoverColor: const Color.fromARGB(255, 235, 234, 234),
    shadowColor: const Color.fromARGB(255, 3, 3, 3).withOpacity(0.2),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFDDDDDD), // Світлий фон для AppBar
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: Colors.black),
    ),
    textTheme:  TextTheme(
      headlineLarge: const TextStyle(
        color: Colors.black87, // Темний відтінок для заголовків
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: const TextStyle(
        color: Colors.black,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: const TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      bodyLarge: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 18,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: const TextStyle(
        color: Color.fromARGB(255, 0, 0, 0),
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: const TextStyle(
        color: Colors.black, // Колір акценту
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: mainColorLight,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: mainColorLight,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color.fromARGB(255, 235, 234, 234), // Світлий фон для текстових полів
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8.0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color.fromRGBO(155, 183, 255, 1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF64B5F6)),
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: mainColorLight, // Колір кнопок
      textTheme: ButtonTextTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor:
          WidgetStateProperty.all(mainColorLight),
      checkColor: WidgetStateProperty.all(Colors.black),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: mainColorLight,
      foregroundColor: Colors.black,
    ),
  );
}
