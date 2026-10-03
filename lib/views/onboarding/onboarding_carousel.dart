import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../app_state/session_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../theme/app_colors.dart';
import '../../widgets/big_button.dart';

class _Slide {
  final String asset; // SVG file in assets/illustrations/
  final IconData fallbackIcon; // shown if the SVG file is missing
  final String title;
  final String text;

  const _Slide({
    required this.asset,
    required this.fallbackIcon,
    required this.title,
    required this.text,
  });
}

/// The slides. To use a different SVG, change only the `asset` name here.
const List<_Slide> _slides = [
  _Slide(
    asset: 'assets/illustrations/upload_documents.svg',
    fallbackIcon: Icons.upload_file_outlined,
    title: 'Apply from home',
    text: 'Send photos of your papers by phone. No long lines.',
  ),
  _Slide(
    asset: 'assets/illustrations/local_guide.svg',
    fallbackIcon: Icons.map_outlined,
    title: 'Find help nearby',
    text: 'See clinics, pharmacies and senior discounts near you.',
  ),
  _Slide(
    asset: 'assets/illustrations/emergency_contact.svg',
    fallbackIcon: Icons.phone_in_talk_outlined,
    title: 'Help in one tap',
    text: 'Press SOS and we call the person you trust right away.',
  ),
  _Slide(
    asset: 'assets/illustrations/choose_role.svg',
    fallbackIcon: Icons.family_restroom_outlined,
    title: 'Family can help',
    text: 'A family member can apply for a senior using Family mode.',
  ),
];

/// Shown once, on the first launch, before the login screen.
class OnboardingCarousel extends StatefulWidget {
  const OnboardingCarousel({super.key});

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<SessionProvider>().advanceTo(OnboardingStage.phoneEntry);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Align(
                alignment: Alignment.centerRight,
                child: _isLast
                    ? null
                    : TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(64, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => _SlideView(slide: _slides[index]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                final active = index == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: active ? 32 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: BigButton(
                label: _isLast ? 'Get started' : 'Next',
                icon: Icons.arrow_forward,
                trailingIcon: true,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 260,
            child: SvgPicture.asset(
              slide.asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    slide.fallbackIcon,
                    size: 96,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
