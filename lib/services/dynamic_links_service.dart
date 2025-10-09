import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/widgets.dart';

class DynamicLinksService {
  static Future<void> handleInitialAndListen(BuildContext context) async {
    // Initial link if app was opened via a dynamic link
    final PendingDynamicLinkData? initialLink =
        await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      _handleLink(context, initialLink.link);
    }

    // Listen for new links while app is in foreground
    FirebaseDynamicLinks.instance.onLink.listen((event) {
      _handleLink(context, event.link);
    });
  }

  static void _handleLink(BuildContext context, Uri link) {
    // Example: route parsing like /summary-info?id=123
    final path = link.path;
    final params = link.queryParameters;
    if (path.contains('summary-info') && params['id'] != null) {
      Navigator.of(context).pushNamed('/summary-info', arguments: params);
    }
    // Extend with more routes as needed
  }
}


