import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'info_card.dart';

/// The page layout shared by every setup screen: green header with the logo,
/// a big title and subtitle, and a white card that overlaps the header.
class OnboardingScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  /// Shows a back arrow in the header when set.
  final VoidCallback? onBack;

  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });

  // Text styles shared by the cards on these screens.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );
  static const TextStyle cardBody = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.45,
  );
  static const TextStyle fieldLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const TextStyle errorText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.danger,
    height: 1.3,
  );
  static const TextStyle linkText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.primary,
  );

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 32),
          child: GreenHeaderStack(
            header: Padding(
              padding: EdgeInsets.fromLTRB(24, topInset + 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (onBack != null) ...[
                        IconButton(
                          tooltip: 'Go back',
                          onPressed: onBack,
                          iconSize: 28,
                          color: Colors.white,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const AppLogo(size: 48),
                      const SizedBox(width: 14),
                      const Flexible(
                        child: Text(
                          'SeniorCompanion',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
            card: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InfoCard(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green header with rounded bottom corners, and a card that sits half on
/// the green and half below it (like the screenshots). Used by onboarding,
/// Home, Wallet and Account.
class GreenHeaderStack extends StatelessWidget {
  final Widget header;
  final Widget card;

  /// How much of the card hangs below the green.
  final double overlap;

  const GreenHeaderStack({
    super.key,
    required this.header,
    required this.card,
    this.overlap = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: overlap,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, card],
        ),
      ],
    );
  }
}

/// The round heart logo.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.favorite_outline,
        color: AppColors.primary,
        size: size * 0.57,
      ),
    );
  }
}
