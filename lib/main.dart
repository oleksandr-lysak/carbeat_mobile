import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/pages/create_master/summary_info_page.dart';
import 'package:carbeat/pages/home/home_page.dart';
import 'package:carbeat/pages/create_master/map_picker_page.dart';
import 'package:carbeat/pages/create_master/master_creation_page.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/pages/home/map_view.dart';
import 'package:carbeat/providers/language_provider.dart';
import 'package:carbeat/providers/notification_provider.dart';
import 'package:carbeat/providers/service_provider.dart';
import 'package:carbeat/providers/theme_provider.dart';
import 'package:carbeat/services/fcm_service.dart';
import 'package:carbeat/services/language_service.dart';
import 'package:carbeat/services/log_service.dart';
import 'package:carbeat/services/api_services/service_service.dart';
import 'package:carbeat/services/token_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:carbeat/widgets/photo_grid_page.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'classes/app_scroll_behavior.dart';
import 'classes/app_themes.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:carbeat/navigation/route_observer.dart';

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      LogService.log('FlutterError: ${details.exception.toString()}');
      LogService.log('Stack trace: ${details.stack.toString()}');
    } else {
      LogService.log(details.toString());
    }
  };

  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  WidgetsFlutterBinding.ensureInitialized();

  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );
  final specialtyService = ServiceService();
  String? savedLanguage = await LanguageService.getLanguage();
  final tokenService = TokenService();
  final token = await tokenService.getToken();
  try {
    await FMTCObjectBoxBackend().initialise();
    await const FMTCStore('mapStore').manage.create();
  } catch (err) {
    LogService.log('Error initializing FMTC: $err');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ServiceProvider(specialtyService),
        ),
        Provider<TokenService>(
          create: (context) => TokenService(),
        ),
        Provider<UserService>(
          create: (context) => UserService(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ThemeProvider(AppThemes.lightTheme),
        ),
        ChangeNotifierProvider(
            create: (context) => LanguageProvider(
                  savedLanguage != null
                      ? Locale(savedLanguage)
                      : const Locale('en'),
                ),),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: MyApp(savedLanguage: savedLanguage, token: token),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? savedLanguage;
  final String? token;

  const MyApp({super.key, this.savedLanguage, this.token});

  static void restartApp(BuildContext context) {
    final MyAppState state = context.findAncestorStateOfType<MyAppState>()!;
    state.restartApp();
  }

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Key key = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FCMService.initializeFCM(context: context);
    });
  }

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
  const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ),
);
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      return Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
        return MaterialApp(
          key: key,
          scrollBehavior: AppScrollBehavior(),
          navigatorObservers: [routeObserver],
          
          localizationsDelegates: [
            FlutterI18nDelegate(
              translationLoader: FileTranslationLoader(
                // 'assets/' prefix is automatically added by FileTranslationLoader,
                // so we specify only the relative folder name here to avoid
                // the duplicated path ("assets/assets/i18n").
                basePath: 'i18n',
                fallbackFile: AppConstants.defaultLanguage,
                forcedLocale: languageProvider.locale,
              ),
              missingTranslationHandler: (key, locale) {},
            ),
          ],
          home: const MapView(),
          routes: {
            '/create-master': (context) => const MasterCreationPage(),
            '/map-picker': (context) => const MapPickerPage(),
            '/photo-grid': (context) => const PhotoGridPage(),
            '/choose-photo': (context) => const PhotoGridPage(),
            '/summary-info': (context) => const SummaryInfoPage(),
            '/home-page': (context) => const HomePage(),
            '/settings-page': (context) => const HomePage(),
          }
        );
      });
    });
  }
}
