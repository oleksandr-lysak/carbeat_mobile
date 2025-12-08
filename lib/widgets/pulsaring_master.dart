import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/master.dart';
import '../constants/app_constants.dart';
import '../constants/styles.dart';

class PulsatingMaster extends StatefulWidget {
  final Master master;
  final bool isActive;

  const PulsatingMaster({super.key, required this.master, this.isActive = false});

  @override
  PulsatingIconState createState() => PulsatingIconState();
}

class PulsatingIconState extends State<PulsatingMaster>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void didUpdateWidget(PulsatingMaster oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldBounce = widget.master.available;
    _controller.stop();
    if (shouldBounce) {
      const double endOffset = -10.0;
      _bounceAnimation = Tween<double>(begin: 0.0, end: endOffset).animate(
        CurvedAnimation(parent: _controller, curve: Curves.bounceInOut),
      );
      _controller.repeat(reverse: true);
    } else {
      _bounceAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.linear),
      );
      _controller.reset();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    final bool shouldBounce = widget.master.available;
    if (shouldBounce) {
      const double endOffset = -10.0;
      _bounceAnimation = Tween<double>(begin: 0.0, end: endOffset).animate(
        CurvedAnimation(parent: _controller, curve: Curves.bounceInOut),
      );
      _controller.repeat(reverse: true);
    } else {
      _bounceAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.linear),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Icon path for fallback
    const String iconPath = 'assets/icons/location.svg';

    // Формуємо повний URL для фото (надійно з базовим URL)
    String photoUrl = '';
    // Prefer thumb if available; fall back to main photo
    final String candidatePath = widget.master.mainThumbUrl.isNotEmpty
        ? widget.master.mainThumbUrl
        : widget.master.mainPhoto;
    if (candidatePath.isNotEmpty) {
      final path = candidatePath;
      if (path.startsWith('http')) {
        photoUrl = path;
      } else {
        final base = AppConstants.publicServerUrl.endsWith('/')
            ? AppConstants.publicServerUrl.substring(0, AppConstants.publicServerUrl.length - 1)
            : AppConstants.publicServerUrl;
        photoUrl = path.startsWith('/') ? '$base$path' : '$base/$path';
      }
    }

    // Стилі обвідки
    final bool isPaid = widget.master.isPremium == true;
    final bool isAvailable = widget.master.available;

    Color outerBorderColor;
    Color innerBorderColor = Colors.transparent;

    final styles = Styles();
    if (isPaid && isAvailable) {
      outerBorderColor = styles.availableColor;
      innerBorderColor = styles.premiumColor;
    } else if (isPaid) {
      outerBorderColor = styles.premiumColor;
    } else if (isAvailable) {
      outerBorderColor = styles.availableColor;
    } else {
      outerBorderColor = styles.unavailableColor;
    }

    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        Widget avatar = Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: outerBorderColor, width: 3),
          ),
          child: innerBorderColor != Colors.transparent
              ? Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: innerBorderColor, width: 2),
                    ),
                    child: ClipOval(
                      child: _buildPhotoOrFallback(photoUrl, iconPath),
                    ),
                  ),
                )
              : ClipOval(child: _buildPhotoOrFallback(photoUrl, iconPath)),
        );

        if (isPaid) {
          avatar = Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Styles().premiumColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        }

        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: avatar,
        );
      },
    );
  }

  Widget _buildPhotoOrFallback(String photoUrl, String iconPath) {
    if (photoUrl.isEmpty) {
      // без плейсхолдера: прозорий контейнер
      return const SizedBox.expand();
    }
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 120),
      // без плейсхолдера: прозоре, поки не завантажиться
      placeholder: (context, url) => const SizedBox.expand(),
      // на помилці показуємо іконку (не під час завантаження)
      errorWidget: (context, url, error) => Center(
        child: SvgPicture.asset(
          iconPath,
          height: 40,
          width: 40,
        ),
      ),
    );
  }
}
