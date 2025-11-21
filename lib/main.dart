import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import 'package:carbeat/providers/service_provider.dart';
import 'package:carbeat/providers/theme_provider.dart';
// FCM removed
import 'package:carbeat/services/analytics_service.dart';
import 'package:carbeat/services/dynamic_links_service.dart';
import 'package:carbeat/services/language_service.dart';
import 'package:carbeat/services/log_service.dart';
import 'package:carbeat/services/update_service.dart';
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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:carbeat/services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
    // Send richer diagnostics to Telegram
    try {
      final exceptionStr = details.exceptionAsString();
      final stackStr = details.stack?.toString() ?? '';
      LogService.log('FlutterError: $exceptionStr');
      if (stackStr.isNotEmpty) {
        LogService.log(stackStr);
      }
    } catch (_) {
      LogService.log(details.toString());
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    // Also log locally
    LogService.log('Uncaught zone error: $error');
    LogService.log(stack.toString());
    return true;
  };

  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(kReleaseMode);

  // Performance collection
  await FirebasePerformance.instance
      .setPerformanceCollectionEnabled(kReleaseMode);
  final specialtyService = ServiceService();
  String? savedLanguage = await LanguageService.getLanguage();
  final tokenService = TokenService();
  final token = await tokenService.getToken();

  // Check auth on app start and try to refresh if needed
  try {
    if (token != null && !await tokenService.isTokenValid()) {
      await ApiService(AppConstants.serverUrl).refreshToken();
    }
  } catch (_) {}

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
                      : WidgetsBinding.instance.window.platformDispatcher.locale,
                ),),
        // NotificationsProvider removed (FCM removed)
      ],
      child: MyApp(savedLanguage: savedLanguage, token: token),
    ),
  );
}

class _LifecycleWrapper extends StatefulWidget {
  final VoidCallback onResumed;
  final Widget child;

  const _LifecycleWrapper({required this.onResumed, required this.child});

  @override
  State<_LifecycleWrapper> createState() => _LifecycleWrapperState();
}

class _LifecycleWrapperState extends State<_LifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Run an initial check once the subtree (including Navigator) is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onResumed();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatefulWidget {
  final String? savedLanguage;
  final String? token;
  const MyApp({super.key, this.savedLanguage, this.token});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_MyAppState>()?.restartApp();
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Key key = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DynamicLinksService.handleInitialAndListen(context);
      AnalyticsService.logAppOpen();
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
          navigatorKey: NavigationService.navigatorKey,
          scrollBehavior: AppScrollBehavior(),
          navigatorObservers: [
            routeObserver,
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          builder: (context, child) {
            // Wrap with a Builder to obtain a context that is a descendant of Navigator.
            // MaterialApp.builder's context is above Navigator, so dialogs would fail.
            return Builder(
              builder: (innerCtx) {
            // Check updates when app resumes to foreground
            return _LifecycleWrapper(
                  onResumed: () => UpdateService.checkForUpdates(innerCtx),
              child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
          
          localizationsDelegates: [
            FlutterI18nDelegate(
              translationLoader: FileTranslationLoader(
                // Point explicitly to the assets translations directory
                basePath: 'assets/i18n',
                fallbackFile: AppConstants.defaultLanguage,
                forcedLocale: languageProvider.locale,
              ),
              missingTranslationHandler: (key, locale) {},
            ),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: languageProvider.locale,
          supportedLocales: const [Locale('en'), Locale('de'), Locale('uk')],
          home: const MapView(),
          routes: {
            '/create-master': (context) => const MasterCreationPage(),
            '/map-picker': (context) => const MapPickerPage(),
            '/photo-grid': (context) => const PhotoGridPage(),
            '/choose-photo': (context) => const PhotoGridPage(),
            '/summary-info': (context) => const SummaryInfoPage(),
            '/home-page': (context) => const HomePage(),
            '/settings-page': (context) => const HomePage(),
          },
        );
      });
    });
  }
}
