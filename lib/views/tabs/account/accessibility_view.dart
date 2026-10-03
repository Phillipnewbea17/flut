import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// Text size, high contrast and language.
class AccessibilityView extends StatelessWidget {
  const AccessibilityView({super.key});

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessibilityProvider>();

    return Scaffold(
      appBar: AppTheme.appBar(context.tr('accountAccessibility')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          InfoCard(
            outlined: true,
            child: Text(
              context.tr('accessPreview'),
              style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 24),
          _Heading(context.tr('accessText')),
          const SizedBox(height: 10),
          for (final option in AccessibilityProvider.textScaleOptions)
            _Option(
              title: option.$2,
              leading: Text(
                'Aa',
                // Fixed size, so the sample shows the difference clearly.
                textScaler: TextScaler.linear(option.$1),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              selected: access.textScale == option.$1,
              onTap: () => access.setTextScale(option.$1),
            ),
          const SizedBox(height: 24),
          _Heading(context.tr('accessContrast')),
          const SizedBox(height: 10),
          InfoCard(
            outlined: true,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: SwitchListTile(
              value: access.highContrast,
              onChanged: access.setHighContrast,
              title: Text(
                context.tr('accessContrast'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                context.tr('accessContrastSub'),
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _Heading(context.tr('accessLanguage')),
          const SizedBox(height: 10),
          for (final language in AppLanguage.values)
            _Option(
              title: language.label,
              leading: const Icon(Icons.translate, color: AppColors.primary, size: 28),
              selected: access.language == language,
              onTap: () => access.setLanguage(language),
            ),
          const SizedBox(height: 8),
          const Text(
            'Some screens are still in English only.',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String title;
  final Widget leading;
  final bool selected;
  final VoidCallback onTap;

  const _Option({
    required this.title,
    required this.leading,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primaryLight : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Center(child: leading)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.primary : AppColors.borderStrong,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}