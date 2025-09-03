import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/master.dart';

class MapCard extends StatelessWidget {
  const MapCard({super.key, required this.item});
  final Master item;

  @override
  Widget build(BuildContext context) {
    String description = item.description;
    String photo = AppConstants.publicServerUrl + item.photo;
    if (description.length > 200) {
      description = '${description.substring(0, 200)}...';
    }
    String address = item.address;
    if (address.length > 27) {
      address = '${address.substring(0, 27)}..';
    }

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: Styles().primaryColor,
          child: Row(
            children: [
              const SizedBox(width: 5),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < item.rating ? Icons.star : Icons.star_border,
                          color:
                              index < item.rating
                                  ? Styles().titleColor
                                  : Styles.descriptionColor,
                        );
                      }),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.name.length > 20 ? '${item.name.substring(0, 22)}...' : item.name,
                      style: TextStyle(
                        fontSize: 24,
                        color: Styles().titleColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Styles.subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Styles.descriptionColor,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Styles.selectedBorder,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: photo,
                            fit: BoxFit.cover,
                            memCacheHeight: 200,
                            placeholder: (context, url) => const SizedBox(
                              width: 100,
                              height: 100,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/images/user_icon.png',
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        fixedSize: const Size(100, 40),
                        backgroundColor: Styles().checkColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final Uri phoneUri = Uri(scheme: 'tel', path: item.phone);
                        if (await canLaunchUrl(phoneUri)) {
                          await launchUrl(
                            phoneUri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                FlutterI18n.translate(
                                  context,
                                  'map_view.call_error',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        FlutterI18n.translate(context, 'map_view.call'),
                        style: TextStyle(fontSize: 16, color: Styles().titleColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
