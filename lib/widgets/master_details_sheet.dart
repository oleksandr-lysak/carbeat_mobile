import 'package:flutter/material.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/models/user.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:carbeat/services/api_services/claim_service.dart';
import 'package:carbeat/services/token_service.dart';
import 'package:carbeat/services/user_service.dart';
import 'package:carbeat/widgets/app_toast.dart';

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

  Future<void> _load({bool refresh = false}) async {
    try {
      if (_data == null || refresh) {
        if (refresh && mounted) {
          setState(() => _loading = true);
        }
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

  Future<void> _startClaimFlow(String initialPhone) async {
    final claimed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClaimFlowSheet(
        masterId: widget.masterId,
        initialPhone: initialPhone,
      ),
    );

    if (claimed == true && mounted) {
      await _load(refresh: true);
      AppToast.show('Профіль підтверджено!', background: Colors.green);
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
    final String phone = data['phone']?.toString() ?? '';
    final bool isClaimed = data['is_claimed'] == true;

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
                              if (!isClaimed) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Styles().checkColor,
                                      foregroundColor: Styles().titleColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () => _startClaimFlow(phone),
                                    child: const Text('Це я'),
                                  ),
                                ),
                              ],
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

class ClaimFlowSheet extends StatefulWidget {
  final int masterId;
  final String? initialPhone;
  const ClaimFlowSheet({super.key, required this.masterId, this.initialPhone});

  @override
  State<ClaimFlowSheet> createState() => _ClaimFlowSheetState();
}

class _ClaimFlowSheetState extends State<ClaimFlowSheet> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final ClaimService _claimService = ClaimService();

  int _step = 0;
  bool _loading = false;
  String? _error;
  String? _submittedPhone;

  @override
  void initState() {
    super.initState();
    if ((widget.initialPhone ?? '').isNotEmpty) {
      _phoneCtrl.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  bool _isPhoneValid(String phone) {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final regex = RegExp(r'^(?:\+?380|0)\d{9}$');
    return regex.hasMatch(clean);
  }

  bool _hasError(Map<String, dynamic> response) {
    if (!response.containsKey('error')) return false;
    final value = response['error'];
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    return value != null;
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (!_isPhoneValid(phone)) {
      setState(() => _error = 'Введіть номер у форматі +380XXXXXXXXX');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _claimService.sendCode(masterId: widget.masterId, phone: phone);
      if (response['status'] == 'sent') {
        setState(() {
          _step = 1;
          _submittedPhone = phone;
        });
      } else if (response['status'] == 'already_claimed') {
        setState(() => _error = 'Профіль вже підтверджено.');
      } else if (_hasError(response)) {
        setState(() => _error = response['message']?.toString() ?? response['error']?.toString() ?? 'Не вдалося надіслати код');
      } else {
        setState(() => _error = 'Не вдалося надіслати код');
      }
    } catch (_) {
      setState(() => _error = 'Сталася помилка. Спробуйте пізніше.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Введіть 6-значний код');
      return;
    }
    final phone = _submittedPhone ?? _phoneCtrl.text.trim();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _claimService.verifyCode(masterId: widget.masterId, phone: phone, code: code);
      if (_hasError(response)) {
        setState(() => _error = response['message']?.toString() ?? response['error']?.toString() ?? 'Код невірний');
        return;
      }
      final accessToken = response['access_token']?.toString();
      final refreshToken = response['refresh_token']?.toString();
      final expiresIn = response['expires_in'] is int ? response['expires_in'] as int : null;
      final userJson = response['user'];

      if (accessToken != null && refreshToken != null && userJson is Map<String, dynamic>) {
        final tokenService = TokenService();
        await tokenService.saveTokens(accessToken, refreshToken, expiresInSeconds: expiresIn);

        final user = User.fromJson(userJson);
        await UserService().saveUserData(user);

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Не вдалося підтвердити профіль');
      }
    } catch (_) {
      setState(() => _error = 'Код невірний або прострочений');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Styles().primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _step == 0 ? 'Підтвердіть профіль' : 'Введіть код',
                  style: TextStyle(
                    color: Styles().titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 0
                      ? 'Щоб підтвердити профіль, введіть свій номер телефону та отримайте SMS-код.'
                      : 'Ми надіслали код підтвердження на ваш номер телефону.',
                  style: const TextStyle(color: Styles.subtitleColor),
                ),
                const SizedBox(height: 20),
                if (_step == 0) ...[
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Номер телефону',
                      hintText: '+380XXXXXXXXX',
                      filled: true,
                      fillColor: Styles().backgroundFormColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Код з SMS',
                      counterText: '',
                      filled: true,
                      fillColor: Styles().backgroundFormColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : _step == 0
                            ? _sendCode
                            : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles().checkColor,
                      foregroundColor: Styles().titleColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_step == 0 ? 'Надіслати код' : 'Підтвердити'),
                  ),
                ),
                if (_step == 1)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _step = 0;
                              _error = null;
                              _submittedPhone = null;
                              _codeCtrl.clear();
                            });
                          },
                    child: const Text('Змінити номер'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}