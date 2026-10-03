import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

/// Plain-language privacy notice.
/// Replace this text with the official notice approved by your LGU's
/// Data Protection Officer before releasing the app.
class PrivacyNoticeView extends StatelessWidget {
  const PrivacyNoticeView({super.key});

  static const List<(String, String)> _sections = [
    (
      'What we collect',
      'Your name, mobile number, birthday, address, emergency contact, and '
          'photos of the papers you send for your Senior Citizen ID.',
    ),
    (
      'Why we collect it',
      'To check if you can get a Senior Citizen ID, to process your '
          'application, to tell you about your benefits, and to contact your '
          'emergency contact when you press SOS.',
    ),
    (
      'Who can see it',
      'Only the staff of your Office for Senior Citizens Affairs (OSCA) and '
          'the offices that need it to give you your benefits.',
    ),
    (
      'How we keep it safe',
      'Your MPIN is stored in encrypted storage on your phone. Photos of '
          'your papers are kept in the app\'s private folder, which other '
          'apps cannot open. Everything is removed from the phone when you '
          'log out.',
    ),
    (
      'Your rights',
      'Under the Data Privacy Act of 2012 (RA 10173), you can ask to see, '
          'correct, or delete your information. Ask your OSCA office or use '
          'Contact us.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Privacy notice'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          for (final section in _sections) ...[
            Semantics(
              header: true,
              child: Text(
                section.$1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              section.$2,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
