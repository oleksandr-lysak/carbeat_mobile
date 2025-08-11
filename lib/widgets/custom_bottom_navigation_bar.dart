import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/services/user_service.dart';
import '../providers/theme_provider.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ThemeProvider themeProvider;
  final Function(int) onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.themeProvider,
    required this.onItemTapped,
  });

  @override
  CustomBottomNavigationBarState createState() =>
      CustomBottomNavigationBarState();
}

class CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  bool isMaster = false;
  bool isLoading = true; // Додаємо прапорець завантаження

  @override
  void initState() {
    super.initState();
    initData(); // Викликаємо тільки при ініціалізації
  }

  Future<void> initData() async {
    bool isMasterCalculate = await UserService().isMaster();
    setState(() {
      isMaster = isMasterCalculate;
      isLoading = false; // Завантаження завершено
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()), // Показуємо індикатор під час завантаження
      );
    }

    var items = _getBottomNavigationItems(isMaster);
    return BottomNavigationBar(
      items: items,
      currentIndex: widget.selectedIndex,
      backgroundColor: widget
          .themeProvider.themeData.bottomNavigationBarTheme.backgroundColor,
      selectedItemColor: widget
          .themeProvider.themeData.bottomNavigationBarTheme.selectedItemColor,
      unselectedItemColor: widget
          .themeProvider.themeData.bottomNavigationBarTheme.unselectedItemColor,
      onTap: widget.onItemTapped,
    );
  }

  List<BottomNavigationBarItem> _getBottomNavigationItems(bool isMaster) {
    if (isMaster) {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: FlutterI18n.translate(context, 'home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.map),
          label: FlutterI18n.translate(context, 'map'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings),
          label: FlutterI18n.translate(context, 'settings'),
        ),
      ];
    } else {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: FlutterI18n.translate(context, 'home'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.settings),
          label: FlutterI18n.translate(context, 'settings'),
        ),
      ];
    }
  }

  
}
