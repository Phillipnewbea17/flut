import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../services/sos_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';

/// How to reach the OSCA office.
class ContactUsView extends StatelessWidget {
  const ContactUsView({super.key});

  /// Put your OSCA office's real number and email here. While they are
  /// empty, the Call and Email buttons stay hidden.
  static const String oscaPhone = '';
  static const String oscaEmail = '';
  static const String officeHours = 'Monday to Friday, 8:00 AM to 5:00 PM';

  Future<void> _open(BuildContext context, Future<bool> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await action();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the app on this phone.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sos = context.read<SosService>();
    final profile = context.watch<UserProvider>().profile;
    final town = (profile?.municipality.isNotEmpty ?? false)
        ? profile!.municipality
        : 'your town';

    return Scaffold(
      appBar: AppTheme.appBar('Contact us'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'OSCA Office',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Office for Senior Citizens Affairs, Municipal Hall of $town',
                  style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.schedule, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        officeHours,
                        style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                if (oscaPhone.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  BigButton(
                    label: 'Call the OSCA office',
                    icon: Icons.call,
                    onPressed: () => _open(context, () => sos.call(oscaPhone)),
                  ),
                ],
                if (oscaEmail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  BigButton(
                    label: 'Send an email',
                    icon: Icons.email_outlined,
                    style: BigButtonStyle.tonal,
                    onPressed: () => _open(
                      context,
                      () => sos.email(oscaEmail, subject: 'SeniorCompanion app'),
                    ),
                  ),
                ],
                if (oscaPhone.isEmpty && oscaEmail.isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'You can visit the office during office hours. Bring your '
                    'valid ID.',
                    style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            outlined: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'In an emergency',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                BigButton(
                  label: 'Call ${SosService.nationalEmergency}',
                  icon: Icons.local_hospital_outlined,
                  color: AppColors.danger,
                  onPressed: () => _open(
                    context,
                    () => sos.call(SosService.nationalEmergency),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
