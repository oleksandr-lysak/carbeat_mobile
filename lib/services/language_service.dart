import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';

class LanguageService {
  static const _languageKey = 'selected_language';

  static Future<void> saveLanguage(BuildContext context, String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    if (!context.mounted) return;
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.setLocale(Locale(languageCode));
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }
}
