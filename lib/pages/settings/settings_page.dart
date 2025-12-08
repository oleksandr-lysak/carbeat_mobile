import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/main.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:carbeat/widgets/buttons.dart';

import '../../services/language_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _HomePageState();
}

class _HomePageState extends State<SettingsPage> {
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  Future<void> _loadSelectedLanguage() async {
    final languageCode = await LanguageService.getLanguage();
    setState(() {
      _selectedLanguage = languageCode;
    });
  }

  void _changeLanguage(BuildContext context, String? languageCode) async {
    if (languageCode != null) {
      await FlutterI18n.refresh(context, Locale(languageCode));
      if (!context.mounted) return;
      await LanguageService.saveLanguage(context, languageCode);
      setState(() {
        _selectedLanguage = languageCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).primaryColor,
          title: Text(AppConstants.appTitle),
        ),
        body: Center(
          child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Column(
                children: [
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    items: AppConstants.languages,
                    onChanged: (String? newValue) {
                      _changeLanguage(context, newValue);
                    },
                  ),
                  Button(
                    labelText:
                        FlutterI18n.translate(context, 'settings_view.logout'),
                    onPressed: () {
                      UserService().deleteUser();
                      MyApp.restartApp(context);
                    },
                    active: true,
                    size: Size.medium,
                    icon: Icons.logout,
                  )
                ],
              )),
        ));
  }
}
