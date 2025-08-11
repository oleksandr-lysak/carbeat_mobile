import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale;

  LanguageProvider(this._locale);

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}