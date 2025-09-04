import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../classes/app_themes.dart';
import '../models/master.dart';
import '../providers/theme_provider.dart';
import '../constants/app_constants.dart';

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

    if (oldWidget.master.available != widget.master.available || oldWidget.master.tariffId != widget.master.tariffId) {
      // Змінюємо анімацію при зміні статусу
      _controller.stop();
      bool shouldBounce = widget.master.tariffId != 2 && widget.master.available;

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
      setState(() {}); // Оновлюємо відображення
    }
  }

  @override
  void initState() {
    super.initState();

    // Enable subtle bounce only for paid masters to add visual emphasis.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    bool shouldBounce = widget.master.tariffId != 2 && widget.master.available;

    if (shouldBounce) {
      const double endOffset = -10.0;
      _bounceAnimation = Tween<double>(begin: 0.0, end: endOffset).animate(
        CurvedAnimation(parent: _controller, curve: Curves.bounceInOut),
      );
      _controller.repeat(reverse: true);
    } else {
      // No animation for free tariff.
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
    ThemeData currentTheme =
        Provider.of<ThemeProvider>(context, listen: true).themeData;

    // Визначаємо шлях до іконки в залежності від теми
    String iconPath = currentTheme == AppThemes.darkTheme
        ? 'assets/icons/location.svg'
        : 'assets/icons/location.svg';

    // Формуємо повний URL для фото
    String photoUrl = widget.master.mainPhoto.isNotEmpty
        ? '${AppConstants.publicServerUrl}${widget.master.mainPhoto}'
        : '';

    // Determine border styling according to tariff & availability.
    final bool isPaid = widget.master.tariffId == 2;
    final bool isAvailable = widget.master.available;

    Color outerBorderColor;
    Color innerBorderColor = Colors.transparent;

    if (isPaid && isAvailable) {
      outerBorderColor = Colors.green; // available outer
      innerBorderColor = const Color(0xFFFFD700); // gold inner
    } else if (isPaid) {
      outerBorderColor = const Color(0xFFFFD700); // gold only
    } else if (isAvailable) {
      outerBorderColor = const Color(0xFF00C853); // green
    } else {
      outerBorderColor = const Color(0xFFBDBDBD); // grey
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
                      child: _buildPhotoOrIcon(photoUrl, iconPath),
                    ),
                  ),
                )
              : ClipOval(child: _buildPhotoOrIcon(photoUrl, iconPath)),
        );

        // Add "top" star label for paid masters.
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
                    color: const Color(0xFFFFD700),
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

  Widget _buildPhotoOrIcon(String photoUrl, String iconPath) {
    return photoUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
          )
        : SvgPicture.asset(
            iconPath,
            height: 100,
            width: 100,
          );
  }
}
