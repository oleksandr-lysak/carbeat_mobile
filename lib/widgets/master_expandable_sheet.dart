import 'package:flutter/material.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/models/master.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class MasterExpandableSheet extends StatefulWidget {
  final Master master;
  const MasterExpandableSheet({super.key, required this.master});

  @override
  State<MasterExpandableSheet> createState() => _MasterExpandableSheetState();
}

class _MasterExpandableSheetState extends State<MasterExpandableSheet> {
  final DraggableScrollableController _controller = DraggableScrollableController();
  double _size = 0.31;
  bool _loadingDetails = false;
  Map<String, dynamic>? _full;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchDetails() async {
    setState(() => _loadingDetails = true);
    try {
      final api = ApiService(AppConstants.serverUrl);
      final res = await api.getRequest('masters/${widget.master.id}');
      _full = res['data'] ?? res;
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  void _expand() async {
    if (_full == null && !_loadingDetails) {
      _fetchDetails();
    }
    await _controller.animateTo(
      0.85,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _callPhone(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося ініціювати дзвінок')),
      );
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
    final bool expanded = _size >= 0.5;
    return DraggableScrollableSheet(
      controller: _controller,
      maxChildSize: 0.95,
      initialChildSize: 0.31,
      minChildSize: 0.31,
      builder: (BuildContext context, ScrollController scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            double extent = notification.extent;
            if (extent < 0.31) extent = 0.31;
            if (extent != _size) {
              setState(() => _size = extent);
              if (extent > 0.5 && !_loadingDetails && _full == null) {
                _fetchDetails();
              }
            }
            return false;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Styles().primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).hintColor,
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _expand,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
                            final scale = Tween<double>(begin: 0.98, end: 1.0).animate(fade);
                            return FadeTransition(
                              opacity: fade,
                              child: ScaleTransition(scale: scale, child: child),
                            );
                          },
                          child: (_size >= 0.5)
                              ? _buildExpandedHeader()
                              : _buildCompactHeader(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
                          final slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOutCubic))
                              .animate(animation);
                          return FadeTransition(
                            opacity: fade,
                            child: SlideTransition(position: slide, child: child),
                          );
                        },
                        child: (_size >= 0.5) ? _buildExpandedBody() : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactHeader() {
    final item = widget.master;
    String description = item.description;
    String address = item.address;
    if (description.length > 200) description = '${description.substring(0, 200)}...';
    if (address.length > 27) address = '${address.substring(0, 27)}..';
    final photo = _buildUrl(item.mainPhoto);

    return Padding(
      key: const ValueKey('compact'),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(5, (index) => Icon(
                        index < item.rating ? Icons.star : Icons.star_border,
                        color: index < item.rating ? Styles().titleColor : Styles.descriptionColor,
                        size: 18,
                      )),
                ),
                const SizedBox(height: 6),
                Text(
                  item.name.length > 22 ? '${item.name.substring(0, 22)}...' : item.name,
                  style: TextStyle(fontSize: 22, color: Styles().titleColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(address, style: const TextStyle(fontSize: 14, color: Styles.subtitleColor)),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 14, color: Styles.descriptionColor)),
                const SizedBox(height: 6),
                Text(item.phone, style: TextStyle(fontSize: 14, color: Styles.selectedBorder)),
                const SizedBox(height: 8),
                if (item.phone.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14.0),
                        backgroundColor: Styles().checkColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      ),
                      onPressed: () => _callPhone(item.phone),
                      child: Text('Подзвонити', style: TextStyle(color: Styles().titleColor)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: photo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photo,
                    fit: BoxFit.cover,
                    width: 100,
                    height: 100,
                  )
                : Container(width: 100, height: 100, color: Styles().backgroundFormColor),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader() {
    final data = _full;
    final name = data?['name']?.toString() ?? widget.master.name;
    final address = data?['address']?.toString() ?? widget.master.address;
    final double rating = (data?['rating'] is num) ? (data?['rating'] as num).toDouble() : widget.master.rating;
    final photos = (data?['photos'] is List) ? (data?['photos'] as List) : [];
    final String mainPhoto = data?['main_photo']?.toString() ?? widget.master.mainPhoto;
    final urls = <String>[
      if (mainPhoto.isNotEmpty) _buildUrl(mainPhoto),
      ...photos.map((p) => _buildUrl(p['url']?.toString() ?? '')).where((u) => u.isNotEmpty),
    ];
    final String phone = data?['phone']?.toString() ?? widget.master.phone;

    return Column(
      key: const ValueKey('expandedHeader'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w700, fontSize: 22)),
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
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      backgroundColor: Styles().checkColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: () => _callPhone(phone),
                    child: Text('Подзвонити', style: TextStyle(color: Styles().titleColor)),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.expand_less),
                color: Styles().titleColor,
                onPressed: _expand,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (urls.isNotEmpty) _buildGallery(urls),
      ],
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

  Widget _buildExpandedBody() {
    if (_loadingDetails && _full == null) {
      return _buildSkeletonBody();
    }
    final data = _full;
    final services = (data?['services'] is List) ? (data?['services'] as List) : [];
    final reviews = (data?['reviews'] is List) ? (data?['reviews'] as List) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Послуги', style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w600, fontSize: 18)),
        ),
        const SizedBox(height: 8),
        _buildServices(services),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('Відгуки', style: TextStyle(color: Styles().titleColor, fontWeight: FontWeight.w600, fontSize: 18)),
        ),
        const SizedBox(height: 8),
        if (reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Поки що немає відгуків', style: const TextStyle(color: Styles.descriptionColor)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = reviews[index] as Map<String, dynamic>;
              final user = r['user'] as Map<String, dynamic>?;
              final double rr = (r['rating'] is num) ? (r['rating'] as num).toDouble() : 0;
              return ListTile(
                title: Text(user?['name']?.toString() ?? 'Анонім', style: TextStyle(color: Styles().titleColor)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(children: List.generate(5, (i) => Icon(i < rr ? Icons.star : Icons.star_border, size: 16, color: i < rr ? Styles().titleColor : Styles.descriptionColor))),
                    const SizedBox(height: 6),
                    Text(r['review']?.toString() ?? '', style: const TextStyle(color: Styles.descriptionColor)),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSkeletonBody() {
    Widget line({double width = double.infinity, double height = 14, double radius = 8}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Styles().backgroundFormColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget chip() {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Styles().backgroundFormColor,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: line(width: 120, height: 18),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(5, (_) => chip()),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: line(width: 100, height: 18),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Styles().backgroundFormColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        line(width: 160, height: 14),
                        const SizedBox(height: 8),
                        line(width: double.infinity, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildServices(List<dynamic> services) {
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
        children: services.map((s) {
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