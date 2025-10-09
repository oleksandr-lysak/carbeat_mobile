import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

import 'analytics_service.dart';
import 'log_service.dart';
import 'remote_config_service.dart';

class UpdateService {
  static const String _lastFlexiblePromptKey = 'last_flexible_prompt_ms';

  static Future<void> checkForUpdates(BuildContext context) async {
    if (!Platform.isAndroid) return; // In-app updates only on Android

    try {
      await RemoteConfigService().initialize();
    } catch (_) {}

    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final minSupported = RemoteConfigService().minSupportedBuild;
    final recommended = RemoteConfigService().recommendedBuild;

    final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

    await AnalyticsService.logEvent('update_check_result', parameters: {
      'current_build': currentBuild.toString(),
      'min_supported': minSupported.toString(),
      'recommended': recommended.toString(),
      'availability': info.updateAvailability.toString(),
      'immediate_allowed': info.immediateUpdateAllowed.toString(),
      'flexible_allowed': info.flexibleUpdateAllowed.toString(),
    });

    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
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
    }
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


