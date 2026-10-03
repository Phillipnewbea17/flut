import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../repositories/user_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Barangay, town and province. The town shows on the Home header.
class ChangeAddressView extends StatefulWidget {
  const ChangeAddressView({super.key});

  @override
  State<ChangeAddressView> createState() => _ChangeAddressViewState();
}

class _ChangeAddressViewState extends State<ChangeAddressView> {
  final TextEditingController _barangay = TextEditingController();
  final TextEditingController _town = TextEditingController();
  final TextEditingController _province = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    _barangay.text = profile?.barangay ?? '';
    _town.text = profile?.municipality ?? '';
    _province.text = profile?.province ?? '';
  }

  @override
  void dispose() {
    _barangay.dispose();
    _town.dispose();
    _province.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = context.read<UserProvider>();
    final users = context.read<UserRepository>();
    final profile = user.profile;
    if (profile == null) return;
    if (_town.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your town or city.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final updated = profile.copyWith(
      barangay: _barangay.text.trim(),
      municipality: _town.text.trim(),
      province: _province.text.trim(),
    );
    await user.updateProfile(updated);
    await users.syncProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address saved.', style: TextStyle(fontSize: 18))),
    );
    if (context.canPop()) context.pop();
  }

  Widget _field(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('My address'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const Text(
            'Your town decides which OSCA office handles your application.',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),
          _field('Barangay', _barangay, 'e.g. Poblacion'),
          _field('Town or city', _town, 'e.g. Ubay'),
          _field('Province', _province, 'e.g. Bohol'),
          if (_error != null) ...[
            Text(_error!, style: OnboardingScaffold.errorText),
            const SizedBox(height: 12),
          ],
          BigButton(
            label: _saving ? 'Saving...' : 'Save address',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
