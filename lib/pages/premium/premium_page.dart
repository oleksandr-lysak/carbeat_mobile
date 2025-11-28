import 'dart:async';
import 'dart:io';

import 'package:carbeat/constants/app_constants.dart';
import 'package:carbeat/constants/styles.dart';
import 'package:carbeat/services/api_services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _loading = true;
  bool _available = false;
  List<ProductDetails> _products = [];
  bool _processingPurchase = false;

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdated, onDone: () {
      _subscription?.cancel();
    }, onError: (_) {
      // ignore
    });
    _initStoreInfo();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initStoreInfo() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (mounted) setState(() {
        _available = false;
        _loading = false;
      });
      return;
    }
    final Set<String> ids = {
      Platform.isIOS
          ? AppConstants.iosPremiumMonthlyProductId
          : AppConstants.androidPremiumMonthlyProductId
    };
    final response = await _iap.queryProductDetails(ids);
    if (mounted) {
      setState(() {
        _available = available;
        _products = response.productDetails;
        _loading = false;
      });
    }
  }

  Future<void> _buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    setState(() => _processingPurchase = true);
    // Subscriptions use buyNonConsumable in the plugin
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _processingPurchase = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Purchase failed')),
            );
          }
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliverAndVerify(p);
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _processingPurchase = false);
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  Future<void> _deliverAndVerify(PurchaseDetails p) async {
    try {
      final token = p.verificationData.serverVerificationData;
      final platform = Platform.isIOS ? 'apple' : 'google';
      final productId = p.productID;
      final api = ApiService(AppConstants.serverUrl);
      final res = await api.postRequest('subscription/check', {
        'platform': platform,
        'receipt_token': token,
        'product_id': productId,
      });
      if (res['active'] == true || (res['data']?['active'] == true)) {
        if (!mounted) return;
        setState(() => _processingPurchase = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium activated')),
        );
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        setState(() => _processingPurchase = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification failed')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _processingPurchase = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium', style: TextStyle(color: Colors.white)),
        backgroundColor: Styles().primaryColor,
        iconTheme: IconThemeData(color: Styles().titleColor),
      ),
      backgroundColor: Styles().primaryColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (!_available
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.white70),
                      const SizedBox(height: 12),
                      const Text(
                        'Магазин недоступний',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Перевірте інтернет та увійдіть у Google Play / App Store.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initStoreInfo,
                        style: ElevatedButton.styleFrom(backgroundColor: Styles().checkColor, elevation: 0),
                        child: Text('Спробувати ще раз', style: TextStyle(color: Styles().titleColor)),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Переваги Premium',
                          style: TextStyle(
                              color: Styles().titleColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const _Benefit(text: 'До 20 фото в галереї'),
                      const _Benefit(text: 'Опис до 2000 символів'),
                      const _Benefit(text: 'До 10 послуг'),
                      const SizedBox(height: 16),
                      // Legal notice about free trial and billing
                      _LegalNotice(products: _products),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      if (_products.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, size: 48, color: Colors.white70),
                                const SizedBox(height: 8),
                                const Text(
                                  'Преміум план тимчасово недоступний',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Спробуйте оновити список або поверніться пізніше.',
                                  style: TextStyle(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(
                                  onPressed: _initStoreInfo,
                                  style: ElevatedButton.styleFrom(backgroundColor: Styles().checkColor, elevation: 0),
                                  child: Text('Оновити список', style: TextStyle(color: Styles().titleColor)),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: _products.length,
                            itemBuilder: (_, i) {
                              final p = _products[i];
                              return Card(
                                color: Styles().backgroundFormColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  title: Text(p.title,
                                      style: TextStyle(
                                          color: Styles().primaryColor,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(p.description,
                                      style:
                                          const TextStyle(color: Colors.white70)),
                                  trailing: _processingPurchase
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator())
                                      : ElevatedButton(
                                          onPressed: () => _buy(p),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Styles().checkColor,
                                              elevation: 0),
                                          child: Text(p.price,
                                              style: TextStyle(
                                                  color: Styles().titleColor)),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: _restore,
                          child: const Text(
                            'Відновити покупки',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
    );
  }

  Future<void> _restore() async {
    await _iap.restorePurchases();
  }
}

class _Benefit extends StatelessWidget {
  final String text;
  const _Benefit({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _LegalNotice extends StatelessWidget {
  final List<ProductDetails> products;
  const _LegalNotice({required this.products});

  String _extractPriceOrDefault() {
    if (products.isNotEmpty) {
      return products.first.price;
    }
    return '9.99 євро/місяць';
  }

  @override
  Widget build(BuildContext context) {
    final priceText = _extractPriceOrDefault();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Перші 30 днів підписки — безкоштовно. Безкоштовний період налаштовується в Google Play / App Store.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          'Після завершення безкоштовного місяця з вас автоматично буде списано $priceText, якщо ви не скасуєте підписку завчасно.',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Оформлюючи підписку, ви погоджуєтесь з ', style: TextStyle(color: Colors.white70)),
            _Link(text: 'Умовами користування', url: 'https://carbeat.online/terms'),
            const Text(' та ', style: TextStyle(color: Colors.white70)),
            _Link(text: 'Політикою конфіденційності', url: 'https://carbeat.online/privacy'),
            const Text('.', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  final String text;
  final String url;
  const _Link({required this.text, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не вдалося відкрити посилання')));
        }
      },
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

