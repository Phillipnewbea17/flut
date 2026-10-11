import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/personal_info.dart';
import '../../../repositories/identity_repository.dart';
import '../../../services/identity_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Ask the OSCA office to correct an official field of the linked senior
/// citizen record (name, birthday, ID number...). Only OSCA can change
/// these; the app only sends the request.
class ProfileCorrectionView extends StatefulWidget {
  final PersonalField? initialField;

  const ProfileCorrectionView({super.key, this.initialField});

  @override
  State<ProfileCorrectionView> createState() => _ProfileCorrectionViewState();
}

class _ProfileCorrectionViewState extends State<ProfileCorrectionView> {
  final TextEditingController _value = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  late PersonalField _field;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialField;
    _field = initial != null && initial.isOscaManaged
        ? initial
        : PersonalField.firstName;
  }

  @override
  void dispose() {
    _value.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_value.text.trim().isEmpty) {
      setState(() => _error = 'Please type the correct ${_field.label}.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Please say why it should be corrected.');
      return;
    }
    final identity = context.read<IdentityRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final request = await identity.requestCorrection(
        field: _field,
        requestedValue: _value.text,
        reason: _reason.text,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          request.localOnly
              ? 'Saved on this phone only. It was NOT sent to OSCA.'
              : 'Your request was sent to the OSCA office.',
          style: const TextStyle(fontSize: 18),
        ),
      ));
      if (context.canPop()) context.pop();
    } on IdentityException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your request was not sent. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current =
        context.watch<IdentityRepository>().profile?.info.valueOf(_field) ?? '';

    return Scaffold(
      appBar: AppTheme.appBar('Ask OSCA to correct'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'Only the OSCA office can change your official information. '
            'Tell them what is wrong and they will check it.',
            style: TextStyle(
                fontSize: 18, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          const Text('What needs correcting?',
              style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          DropdownButtonFormField<PersonalField>(
            initialValue: _field,
            isExpanded: true,
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
            items: [
              for (final f in PersonalFieldInfo.oscaManaged)
                DropdownMenuItem(value: f, child: Text(f.label)),
            ],
            onChanged: _sending
                ? null
                : (f) => setState(() {
                      if (f != null) _field = f;
                      _error = null;
                    }),
          ),
          const SizedBox(height: 16),
          Text(
            'Now: ${current.isEmpty ? 'not set' : current}',
            style: const TextStyle(fontSize: 18, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          const Text('Correct value', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _value,
            enabled: !_sending,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          const Text('Why?', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: _reason,
            enabled: !_sending,
            maxLines: 3,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(
                hintText: 'e.g. My birthday is wrong on the record.'),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: OnboardingScaffold.errorText),
            const SizedBox(height: 12),
          ],
          BigButton(
            label: _sending ? 'Sending...' : 'Send to OSCA',
            icon: Icons.send_outlined,
            onPressed: _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}
