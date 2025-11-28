import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import 'analytics_service.dart';
import 'log_service.dart';
import 'remote_config_service.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/services/navigation_service.dart';
import 'package:carbeat/constants/styles.dart';

class UpdateService {
  static const String _lastFlexiblePromptKey = 'last_flexible_prompt_ms';

  static Future<void> checkForUpdates(BuildContext context) async {
    // 1) Load backend versions first (source of truth)
    try {
      await RemoteConfigService().initialize(); // used for throttle only
    } catch (_) {}

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final backend = await _getBackendVersionDataSafe();
    final minSupported = backend['min_supported_build'] ?? 1;
    final recommended = backend['recommended_build'] ?? 1;
    final storeUrl = backend['store_url'] as String?;
    final serverMessage = backend['message'] as String?;

    // 2) Mandatory block regardless of platform/APIs
    if (currentBuild < minSupported) {
      final dialogCtx = await _awaitNavigatorContext(context);
      if (dialogCtx != null) {
        await _showBackendBlockingDialog(dialogCtx, serverMessage, storeUrl);
      }
      return;
    }

    // 3) Android Play Core path; on other platforms, show soft prompt if below recommended
    if (!Platform.isAndroid) {
      if (currentBuild < recommended) {
        final shouldPrompt = await _shouldPromptFlexible();
        if (shouldPrompt) {
          final dialogCtx = await _awaitNavigatorContext(context);
          if (dialogCtx != null) {
            await _showBackendSoftPrompt(dialogCtx);
          }
          await _markFlexiblePrompted();
        }
      }
      return;
    }

    AppUpdateInfo? info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } on PlatformException catch (e) {
      // Common in sideload/debug builds: app not owned in Play Store (ERROR_APP_NOT_OWNED / -10).
      LogService.log('InAppUpdate.checkForUpdate PlatformException: $e');
      await AnalyticsService.logEvent('update_check_failed', parameters: {
        'error': e.toString(),
        'code': e.code,
        'message': e.message ?? '',
      });

      // Fallback: for builds below recommended, still show soft backend prompt (non-blocking).
      if (currentBuild < recommended) {
        final shouldPrompt = await _shouldPromptFlexible();
        if (shouldPrompt) {
          final dialogCtx = await _awaitNavigatorContext(context);
          if (dialogCtx != null) {
            await _showBackendSoftPrompt(dialogCtx);
          }
          await _markFlexiblePrompted();
        }
      }
      return;
    } catch (e) {
      LogService.log('InAppUpdate.checkForUpdate error: $e');
      await AnalyticsService.logEvent('update_check_failed', parameters: {
        'error': e.toString(),
      });
      if (currentBuild < recommended) {
        final shouldPrompt = await _shouldPromptFlexible();
        if (shouldPrompt) {
          final dialogCtx = await _awaitNavigatorContext(context);
          if (dialogCtx != null) {
            await _showBackendSoftPrompt(dialogCtx);
          }
          await _markFlexiblePrompted();
        }
      }
      return;
    }

    await AnalyticsService.logEvent('update_check_result', parameters: {
      'current_build': currentBuild.toString(),
      'min_supported': minSupported.toString(),
      'recommended': recommended.toString(),
      'availability': info.updateAvailability.toString(),
      'immediate_allowed': info.immediateUpdateAllowed.toString(),
      'flexible_allowed': info.flexibleUpdateAllowed.toString(),
    });

    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      // No Play Core update available → still show soft prompt if below recommended
      if (currentBuild < recommended) {
        final shouldPrompt = await _shouldPromptFlexible();
        if (shouldPrompt) {
          final dialogCtx = await _awaitNavigatorContext(context);
          if (dialogCtx != null) {
            await _showBackendSoftPrompt(dialogCtx);
          }
          await _markFlexiblePrompted();
        }
      }
      return;
    }

    if (currentBuild < minSupported && info.immediateUpdateAllowed) {
      await _runImmediateUpdate(context);
      return;
    }

    if (currentBuild < recommended && info.flexibleUpdateAllowed) {
      final shouldPrompt = await _shouldPromptFlexible();
      if (shouldPrompt) {
        await _promptFlexibleUpdate(context);
        await _markFlexiblePrompted();
      }
    } else if (currentBuild < recommended) {
      // Fallback: show a lightweight soft prompt when Play Core API reports no update available
      // but backend recommends updating (common in debug/non-Play installs).
      final shouldPrompt = await _shouldPromptFlexible();
      if (shouldPrompt) {
        await _showBackendSoftPrompt(context);
        await _markFlexiblePrompted();
      }
    }
  }

  static Future<Map<String, dynamic>> _getBackendVersionDataSafe() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String platform = Platform.isIOS ? 'ios' : 'android';
      final candidates = <String>{
        AppConstants.serverUrl,
        '${AppConstants.publicServerUrl}api/',
      }.toList();
      for (final base in candidates) {
        try {
          final api = ApiService(base);
          final res = await api.getRequest('app/version?platform=$platform&build=$currentBuild');
          final data = (res.containsKey('data') && res['data'] is Map<String, dynamic>)
              ? (res['data'] as Map<String, dynamic>)
              : res;
          final min = (data['min_supported_build'] is num) ? (data['min_supported_build'] as num).toInt() : 1;
          final rec = (data['recommended_build'] is num) ? (data['recommended_build'] as num).toInt() : 1;
          return {
            'min_supported_build': min,
            'recommended_build': rec,
            'store_url': (data['store_url'] as String?)?.trim(),
            'message': (data['message'] as String?)?.trim(),
          };
        } catch (_) {/* try next */}
      }
    } catch (_) {}
    return {
      'min_supported_build': 1,
      'recommended_build': 1,
      'store_url': null,
      'message': null,
    };
  }

  static Future<bool> _checkBackendAndBlockIfNeeded(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String platform = Platform.isIOS ? 'ios' : 'android';
      // Try primary API base; if it fails, retry with public base as a fallback.
      final candidates = <String>{
        AppConstants.serverUrl,
        '${AppConstants.publicServerUrl}api/',
      }.toList();

      Map<String, dynamic>? data;
      for (final base in candidates) {
        try {
          final api = ApiService(base);
      final res = await api.getRequest('app/version?platform=$platform&build=$currentBuild');
          data = (res.containsKey('data') && res['data'] is Map<String, dynamic>)
              ? (res['data'] as Map<String, dynamic>)
              : res;
          break;
        } catch (_) {
          // try next candidate
        }
      }
      if (data == null) {
        throw Exception('All version endpoints failed');
      }
      final int minSupported = (data['min_supported_build'] is num) ? (data['min_supported_build'] as num).toInt() : 1;
      final String? storeUrl = (data['store_url'] as String?)?.trim();
      final String? message = (data['message'] as String?)?.trim();

      if (currentBuild < minSupported) {
        await AnalyticsService.logEvent('update_block_backend', parameters: {
          'platform': platform,
          'current_build': currentBuild.toString(),
          'min_supported': minSupported.toString(),
        });
        await _showBackendBlockingDialog(context, message, storeUrl);
        return true;
      }
    } catch (err) {
      // If backend check fails, proceed with normal flow
      LogService.log('Backend version check failed: $err');
    }
    return false;
  }

  static Future<void> _showBackendSoftPrompt(BuildContext context) async {
    final title = FlutterI18n.translate(context, 'update.title');
    final body = FlutterI18n.translate(context, 'update.body_recommended');
    final openStoreText = Platform.isIOS
        ? FlutterI18n.translate(context, 'update.open_appstore')
        : FlutterI18n.translate(context, 'update.open_play');
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(FlutterI18n.translate(context, 'update.later')),
            ),
            ElevatedButton(
              onPressed: () async {
                  await _openStore();
                await AnalyticsService.logEvent('update_store_opened_soft');
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(openStoreText),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _showBackendBlockingDialog(BuildContext context, String? message, String? storeUrl) async {
    try {
      final title = FlutterI18n.translate(context, 'update.title');
      final body = message?.isNotEmpty == true
          ? message!
          : FlutterI18n.translate(context, 'update.body_critical');
      final openStoreText = Platform.isIOS
          ? FlutterI18n.translate(context, 'update.open_appstore')
          : FlutterI18n.translate(context, 'update.open_play');

      final ctx = _dialogContextOr(context);
      if (ctx == null || !ctx.mounted) return;
      await showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final brand = Styles().primaryColor;
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              elevation: 8,
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: brand.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.system_update, color: brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                ],
              ),
              content: Text(body, style: theme.textTheme.bodyMedium),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      if (storeUrl != null && storeUrl.isNotEmpty) {
                        await launchUrlString(storeUrl);
                      } else {
                        await _openStore();
                      }
                      await AnalyticsService.logEvent('update_store_opened_backend');
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: Text(openStoreText),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (_) {
      final ctx = _dialogContextOr(context);
      if (ctx != null) {
        await _showPlainBlockingDialog(ctx, message);
      }
    }
  }

  static Future<void> _showPlainBlockingDialog(BuildContext context, String? message) async {
    final ctx = _dialogContextOr(context);
    if (ctx == null || !ctx.mounted) return;
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final brand = Styles().primaryColor;
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            elevation: 8,
            backgroundColor: theme.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: brand),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Update required')),
              ],
            ),
            content: Text(
              message?.isNotEmpty == true ? message! : 'A newer version of the app is required to continue.',
              style: theme.textTheme.bodyMedium,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await _openStore();
                    await AnalyticsService.logEvent('update_store_opened_backend_plain');
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(Platform.isIOS ? 'Open App Store' : 'Open Play Store'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static BuildContext? _dialogContextOr(BuildContext context) {
    if (Navigator.maybeOf(context) != null) return context;
    return NavigationService.navigatorKey.currentContext;
  }

  static Future<BuildContext?> _awaitNavigatorContext(BuildContext context) async {
    if (Navigator.maybeOf(context) != null) return context;
    for (int i = 0; i < 90; i++) {
      final ctx = NavigationService.navigatorKey.currentContext;
      if (ctx != null && Navigator.maybeOf(ctx) != null) {
        return ctx;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
    return NavigationService.navigatorKey.currentContext;
  }

  static Future<void> _runImmediateUpdate(BuildContext context) async {
    try {
      await AnalyticsService.logEvent('update_immediate_started');
      await InAppUpdate.performImmediateUpdate();
    } catch (err) {
      LogService.log('Immediate update failed: $err');
      await AnalyticsService.logEvent('update_immediate_failed', parameters: {
        'error': err.toString(),
      });
      await _showBlockingStoreDialog(context);
    }
  }

  static Future<void> _promptFlexibleUpdate(BuildContext context) async {
    final title = FlutterI18n.translate(context, 'update.title');
    final body = FlutterI18n.translate(context, 'update.body_recommended');
    final updateNow = FlutterI18n.translate(context, 'update.update_now');
    final later = FlutterI18n.translate(context, 'update.later');
    final downloading = FlutterI18n.translate(context, 'update.downloading');
    final restartNow = FlutterI18n.translate(context, 'update.restart_now');

    await AnalyticsService.logEvent('update_prompt_shown', parameters: {
      'type': 'flexible',
    });

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool downloadingState = false;
        bool readyToInstall = false;
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!downloadingState && !readyToInstall) Text(body),
                if (downloadingState && !readyToInstall)
                  Row(
                    children: [
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(downloading)),
                    ],
                  ),
                if (readyToInstall) Text(FlutterI18n.translate(context, 'update.ready_to_install')),
              ],
            ),
            actions: [
              if (!downloadingState && !readyToInstall)
                TextButton(
                  onPressed: () {
                    AnalyticsService.logEvent('update_prompt_declined');
                    Navigator.of(ctx).pop();
                  },
                  child: Text(later),
                ),
              if (!downloadingState && !readyToInstall)
                ElevatedButton(
                  onPressed: () async {
                    await AnalyticsService.logEvent('update_prompt_accepted');
                    setState(() => downloadingState = true);
                    try {
                      await AnalyticsService.logEvent('update_flexible_started');
                      await InAppUpdate.startFlexibleUpdate();
                      setState(() {
                        downloadingState = false;
                        readyToInstall = true;
                      });
                    } catch (err) {
                      setState(() => downloadingState = false);
                      LogService.log('Flexible update failed: $err');
                      await AnalyticsService.logEvent('update_flexible_failed', parameters: {
                        'error': err.toString(),
                      });
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    }
                  },
                  child: Text(updateNow),
                ),
              if (readyToInstall)
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await InAppUpdate.completeFlexibleUpdate();
                      await AnalyticsService.logEvent('update_flexible_completed');
                    } catch (err) {
                      LogService.log('Complete flexible update failed: $err');
                      await AnalyticsService.logEvent('update_flexible_failed', parameters: {
                        'error': err.toString(),
                      });
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(restartNow),
                ),
            ],
          );
        });
      },
    );
  }

  static Future<void> _showBlockingStoreDialog(BuildContext context) async {
    final title = FlutterI18n.translate(context, 'update.title');
    final body = FlutterI18n.translate(context, 'update.body_critical');
    final openPlay = FlutterI18n.translate(context, 'update.open_play');

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _openStore();
                await AnalyticsService.logEvent('update_store_opened');
              },
              child: Text(openPlay),
            ),
          ],
        );
      },
    );
  }

  static Future<bool> _shouldPromptFlexible() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastFlexiblePromptKey);
    final throttleHours = RemoteConfigService().flexibleThrottleHours;
    if (last == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - last;
    return elapsed > Duration(hours: throttleHours).inMilliseconds;
  }

  static Future<void> _markFlexiblePrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastFlexiblePromptKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _openStore() async {
    // Try to open Play Store app, fallback to web
    const marketUrl = 'market://details?id=';
    const webUrl = 'https://play.google.com/store/apps/details?id=';
    final packageInfo = await PackageInfo.fromPlatform();
    final id = packageInfo.packageName;
    final tryMarket = await launchUrlString('$marketUrl$id');
    if (!tryMarket) {
      await launchUrlString('$webUrl$id');
    }
  }
}


