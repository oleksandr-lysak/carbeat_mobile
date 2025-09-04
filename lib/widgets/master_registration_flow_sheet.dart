import 'package:flutter/material.dart';
import 'package:carbeat/pages/create_master/map_picker_page.dart';
import 'package:carbeat/pages/create_master/master_creation_page.dart';
import 'package:carbeat/widgets/photo_grid_page.dart';
import 'package:carbeat/pages/create_master/summary_info_page.dart';

class MasterRegistrationFlowSheet extends StatelessWidget {
  final String phone;
  final BuildContext parentContext;

  const MasterRegistrationFlowSheet({super.key, required this.phone, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.92;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Navigator(
          initialRoute: '/map-picker',
          onGenerateRoute: (RouteSettings settings) {
            switch (settings.name) {
              case '/map-picker':
                return MaterialPageRoute(
                  settings: RouteSettings(name: '/map-picker', arguments: {'phone': phone}),
                  builder: (_) => const MapPickerPage(),
                  maintainState: true,
                );
              case '/create-master':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const MasterCreationPage(),
                  maintainState: true,
                );
              case '/choose-photo':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const PhotoGridPage(),
                  maintainState: true,
                );
              case '/summary-info':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const SummaryInfoPage(),
                  maintainState: true,
                );
              case '/home-page':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) {
                    Future.microtask(() {
                      Navigator.of(parentContext, rootNavigator: true).pop(true);
                    });
                    return const SizedBox.shrink();
                  },
                );
              default:
                return MaterialPageRoute(
                  builder: (_) => const SizedBox.shrink(),
                );
            }
          },
        ),
      ),
    );
  }
} 