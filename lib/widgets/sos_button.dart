import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_state/accessibility_provider.dart';
import '../app_state/user_provider.dart';
import '../routes/app_router.dart';
import '../services/sos_service.dart';
import '../theme/app_colors.dart';
import 'big_button.dart';

/// Big red SOS button on the Home tab. Opens a sheet so a wrong tap does not
/// call anyone by accident.
class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'SOS. Get help now',
      child: SizedBox(
        height: 72,
        child: FloatingActionButton.extended(
          heroTag: 'sos-button',
          onPressed: () => showSosSheet(context),
          backgroundColor: AppColors.danger,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.call, size: 30),
          label: Text(
            context.tr('sosLabel'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

Future<void> showSosSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheetContext) => const _SosSheet(),
  );
}

class _SosSheet extends StatelessWidget {
  const _SosSheet();

  Future<void> _run(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await action();
    navigator.pop();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the phone app. Please dial the number yourself.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final contact = user.emergencyContact;
    final sos = context.read<SosService>();
    final name = user.profile?.fullName ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Get help now',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose who to contact.',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (contact != null) ...[
            BigButton(
              label: 'Call ${contact.name}',
              icon: Icons.call,
              color: AppColors.danger,
              onPressed: () => _run(context, () => sos.callContact(contact)),
            ),
            const SizedBox(height: 14),
            BigButton(
              label: 'Text ${contact.name}',
              icon: Icons.sms_outlined,
              style: BigButtonStyle.tonal,
              onPressed: () => _run(
                context,
                () => sos.textContact(
                  contact,
                  'This is ${name.isEmpty ? 'your family member' : name}. '
                  'I need help. Please call me now.',
                ),
              ),
            ),
          ] else ...[
            const Text(
              'You have no emergency contact yet.',
              style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            BigButton(
              label: 'Add emergency contact',
              icon: Icons.person_add_alt_1_outlined,
              style: BigButtonStyle.tonal,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.emergencyContact);
              },
            ),
          ],
          const SizedBox(height: 14),
          BigButton(
            label: 'Call ${SosService.nationalEmergency} emergency',
            icon: Icons.local_hospital_outlined,
            color: AppColors.primaryDark,
            onPressed: () =>
                _run(context, () => sos.call(SosService.nationalEmergency)),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(minimumSize: const Size(48, 56)),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
