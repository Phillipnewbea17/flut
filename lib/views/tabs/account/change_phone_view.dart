import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../repositories/user_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/green_page_header.dart';
import '../../../widgets/phone_field.dart';

/// Add, change or remove the contact number OSCA staff ring the senior on.
///
/// Signing in uses the email address, so the number is ordinary contact
/// information: it may be left empty and changing it never touches the
/// session or the password.
class ChangePhoneView extends StatefulWidget {
  const ChangePhoneView({super.key});

  @override
  State<ChangePhoneView> createState() => _ChangePhoneViewState();
}

class _ChangePhoneViewState extends State<ChangePhoneView> {
  final TextEditingController _phone = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final phone = context.read<UserProvider>().profile?.phone ?? '';
    if (phone.isNotEmpty) _phone.text = PhoneNumberFormatter.format(phone);
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = context.read<UserProvider>();
    final users = context.read<UserRepository>();
    final profile = user.profile;
    if (profile == null) return;

    final digits = UserProvider.normalizePhone(_phone.text);
    // Empty means "I have no number to give", which is allowed.
    if (digits.isNotEmpty && !UserProvider.isValidPhone(digits)) {
      setState(() => _error =
          'Please enter your 10-digit mobile number. It starts with 9.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });

    final updated = profile.copyWith(phone: digits);
    // The OSCA office calls this number, so it only counts as saved once the
    // server has it. Offline, nothing changes and the senior is told why.
    final problem = await users.syncProfile(updated);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _saving = false;
        _error = problem;
      });
      return;
    }
    await user.updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          digits.isEmpty ? 'Phone number removed.' : 'Phone number saved.',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const GreenPageHeader(
            title: 'Phone Number',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'So the OSCA office can call you about your requests. '
                'You still log in with your email address.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 17, height: 1.4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                PhoneField(
                  controller: _phone,
                  enabled: !_saving,
                  hasError: error != null,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _save(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error,
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'You can leave this empty if you have no mobile number.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, 8, 24, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: BigButton(
            label: _saving ? 'Saving...' : 'Save phone number',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}
