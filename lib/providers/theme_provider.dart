import 'package:flutter/material.dart';
import 'package:carbeat/constants/app_constants.dart';

import '../classes/app_themes.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData;

  ThemeProvider(this._themeData);

  ThemeData get themeData => _themeData;

  void toggleTheme() {
    if (_themeData == AppThemes.lightTheme) {
      _themeData = AppThemes.darkTheme;
      AppConstants().mapBoxStyleId = AppConstants.mapBoxStyleIdDark;
    } else {
      _themeData = AppThemes.lightTheme;
      AppConstants().mapBoxStyleId = AppConstants.mapBoxStyleIdLight;
    }
    notifyListeners();
  }
}
