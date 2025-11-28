import 'package:flutter/material.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/services/api_services/api_service.dart';

class MasterDetailsSheet extends StatefulWidget {
  final int masterId;
  final Map<String, dynamic>? initialData;
  const MasterDetailsSheet({super.key, required this.masterId, this.initialData});

  @override
  State<MasterDetailsSheet> createState() => _MasterDetailsSheetState();
}

class _MasterDetailsSheetState extends State<MasterDetailsSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _loading = _data == null;
    _load();
  }

  Future<void> _load() async {
    try {
      if (_data == null) {
        final api = ApiService(AppConstants.serverUrl);
        final res = await api.getRequest('masters/${widget.masterId}');
        _data = res['data'] ?? res;
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConstants.publicServerUrl.endsWith('/')
        ? AppConstants.publicServerUrl.substring(0, AppConstants.publicServerUrl.length - 1)
        : AppConstants.publicServerUrl;
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Styles().primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final data = _data ?? {};
    final String name = data['name']?.toString() ?? '';
    final String address = data['address']?.toString() ?? '';
    final double rating = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0;

    final List<dynamic> photos = (data['photos'] is List) ? (data['photos'] as List) : [];
    final String mainPhoto = data['main_photo']?.toString() ?? '';
    final List<String> imageUrls = [
      if (mainPhoto.isNotEmpty) _buildUrl(mainPhoto),
      ...photos.map((p) => _buildUrl(p['url']?.toString() ?? '')).where((u) => u.isNotEmpty),
    ];

    final List<dynamic> services = (data['services'] is List) ? (data['services'] as List) : [];
    final String? primaryServiceName = services
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (s) => (s['is_primary'] ?? false) == true,
          orElse: () => <String, dynamic>{},
        )['name']?.toString();
    final List<dynamic> reviews = (data['reviews'] is List) ? (data['reviews'] as List) : [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).hintColor,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Styles().titleColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(address, style: const TextStyle(color: Styles.subtitleColor)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  ...List.generate(5, (i) => Icon(
                                        i < rating ? Icons.star : Icons.star_border,
                                        size: 18,
                                        color: i < rating ? Styles().titleColor : Styles.descriptionColor,
                                      )),
                                  const SizedBox(width: 8),
                                  Text(rating.toStringAsFixed(1), style: const TextStyle(color: Styles.descriptionColor)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Styles().titleColor,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (imageUrls.isNotEmpty) _buildGallery(imageUrls),
                  const SizedBox(height: 16),
                  if (primaryServiceName != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Основна послуга', style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w600, fontSize: 18)),
                          const SizedBox(height: 6),
                          Text(primaryServiceName, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Додаткові послуги', style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w600, fontSize: 18)),
                  ),
                  const SizedBox(height: 8),
                  _buildServices(services, primaryName: primaryServiceName),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Відгуки', style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w600, fontSize: 18)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            reviews.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Поки що немає відгуків', style: const TextStyle(color: Styles.descriptionColor)),
                    ),
                  )
                : SliverList.separated(
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = reviews[index] as Map<String, dynamic>;
                      final user = r['user'] as Map<String, dynamic>?;
                      final double rr = (r['rating'] is num) ? (r['rating'] as num).toDouble() : 0;
                      return ListTile(
                        title: Text(
                          user?['name']?.toString() ?? 'Анонім',
                          style: TextStyle(color: Styles().titleColor),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: List.generate(5, (i) => Icon(
                                    i < rr ? Icons.star : Icons.star_border,
                                    size: 16,
                                    color: i < rr ? Styles().titleColor : Styles.descriptionColor,
                                  )),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r['review']?.toString() ?? '',
                              style: const TextStyle(color: Styles.descriptionColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  Widget _buildGallery(List<String> urls) {
    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _currentPhoto = i),
              controller: PageController(viewportFraction: 0.9),
              itemBuilder: (context, index) {
                final url = urls[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPhoto ? Styles().titleColor : Styles.descriptionColor,
                  ),
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildServices(List<dynamic> services, {String? primaryName}) {
    if (services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Text('Список послуг відсутній', style: const TextStyle(color: Styles.descriptionColor)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: services.where((s) {
          final name = s['name']?.toString() ?? '';
          return primaryName == null || name != primaryName;
        }).map((s) {
          final name = s['name']?.toString() ?? '';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Styles().backgroundFormColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(name, style: TextStyle(color: Styles().primaryColor)),
          );
        }).toList(),
      ),
    );
  }
} 