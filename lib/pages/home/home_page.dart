import 'package:flutter/material.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/pages/home/map_view.dart';

import '../../services/language_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? selectedLanguage;

  @override
  void initState() {
    super.initState();
    loadSelectedLanguage();
  }

  Future<void> loadSelectedLanguage() async {
    final languageCode = await LanguageService.getLanguage();
    setState(() {
      selectedLanguage = languageCode;
    });
  }

  void onLanguageChanged(String? languageCode) {
    setState(() {
      selectedLanguage = languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appTitle),
      ),
      body: const MapView(),
    );
  }
}
