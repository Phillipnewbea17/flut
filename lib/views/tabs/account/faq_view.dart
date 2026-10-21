import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

class FaqView extends StatelessWidget {
  const FaqView({super.key});

  static const List<(String, String)> _faqs = [
    (
      'Who can get a Senior Citizen ID?',
      'Filipino citizens who are 60 years old or above and live in the town '
          'where they apply.',
    ),
    (
      'What papers do I need?',
      'Four papers: a valid ID, your birth certificate, a proof of residence '
          '(barangay certificate or utility bill), and a 2x2 photo. You can '
          'send photos of them in Upload documents.',
    ),
    (
      'How long does it take?',
      'It depends on your OSCA office. You will get a notification in this '
          'app when your application is checked and when your ID is ready.',
    ),
    (
      'What password should I use?',
      'Any password of at least 8 characters. A few short words together, '
          'like "bahay sa ubay", is easy to remember and hard to guess. Do '
          'not share it with anyone.',
    ),
    (
      'I forgot my password. What do I do?',
      'On the login screen, tap "Forgot password?" and enter your email '
          'address. We will email you a link. Open the email, tap "Set a new '
          'password", then come back and log in. The link works for 30 '
          'minutes.',
    ),
    (
      'Why do I have to confirm my email?',
      'It makes sure the address is really yours, so nobody else can use it '
          'and so we can reach you about your password. After you sign up, '
          'open our email and tap "Confirm my email". If it is not there, '
          'look in your Spam or Junk folder.',
    ),
    (
      'Can my family help me?',
      'Yes. A family member can install the app, choose "I am a Family '
          'Relative", and send papers for you using Family mode.',
    ),
    (
      'What does the SOS button do?',
      'It lets you call or text your emergency contact, or call 911, with '
          'big buttons. You can change your emergency contact in Account.',
    ),
    (
      'The store did not give my discount. What can I do?',
      'On Home, tap Help & Complaints, then choose "Discount problem". The '
          'OSCA office can follow it up.',
    ),
    (
      'Can I make the letters bigger?',
      'Yes. Go to Account, then Text size and language.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Questions and answers'),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        itemCount: _faqs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final question = _faqs[index].$1;
          final answer = _faqs[index].$2;
          return Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              shape: const Border(),
              collapsedShape: const Border(),
              expandedAlignment: Alignment.centerLeft,
              title: Text(
                question,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              children: [
                Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
