import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:carbeat/services/api_services/claim_service.dart';
import 'package:carbeat/services/claim_link_manager.dart';
import 'package:carbeat/widgets/app_toast.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/widgets.dart';

class DynamicLinksService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _appLinkSubscription;

  static Future<void> handleInitialAndListen(BuildContext context) async {
    // Initial link if app was opened via a dynamic link
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      await _handleLink(context, initialLink.link);
    }

    // Listen for new links while app is in foreground
    FirebaseDynamicLinks.instance.onLink.listen((event) {
      _handleLink(context, event.link);
    });

    await _initAppLinks(context);
  }

  static Future<void> _initAppLinks(BuildContext context) async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleLink(context, initialUri);
      }
    } catch (_) {
      // Ignore malformed initial URIs
    }

    _appLinkSubscription?.cancel();
    _appLinkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri != null) {
          _handleLink(context, uri);
        }
      },
      onError: (_) {
        // Ignore stream errors
      },
    );
  }

  static Future<void> _handleLink(BuildContext context, Uri link) async {
    // Example: route parsing like /summary-info?id=123
    final path = link.path;
    final params = link.queryParameters;
    if (path.contains('summary-info') && params['id'] != null) {
      Navigator.of(context).pushNamed('/summary-info', arguments: params);
    }
    final segments = link.pathSegments;
    String? token;
    if (segments.length >= 2 && segments[0] == 'claim') {
      token = segments[1];
    } else if (link.host == 'claim' && segments.isNotEmpty) {
      token = segments[0];
    }
    if (token != null) {
      if (token.isEmpty) return;
      try {
        final response = await ClaimService().getClaimStatus(token);
        final masterIdParam = params['master_id'] ?? response['master_id']?.toString();
        final masterId = masterIdParam != null ? int.tryParse(masterIdParam) : null;
        if (masterId != null) {
          ClaimLinkManager.dispatch(ClaimLinkPayload(masterId: masterId, token: token));
          AppToast.show('Відкриваємо профіль майстра');
        } else {
          AppToast.show('Не вдалося знайти майстра', background: const Color(0xFFB00020));
        }
      } catch (_) {
        AppToast.show('Посилання недійсне або прострочене', background: const Color(0xFFB00020));
      }
    }
  }
}
