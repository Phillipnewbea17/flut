import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../repositories/user_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/green_page_header.dart';
import '../../../widgets/icon_tile.dart';
import '../../../widgets/onboarding_scaffold.dart';

/// Purok / street, barangay, town and province, in the same green-header
/// design as Personal information. The town shows on the Home header.
class ChangeAddressView extends StatefulWidget {
  const ChangeAddressView({super.key});

  @override
  State<ChangeAddressView> createState() => _ChangeAddressViewState();
}

class _ChangeAddressViewState extends State<ChangeAddressView> {
  final TextEditingController _street = TextEditingController();
  final TextEditingController _barangay = TextEditingController();
  final TextEditingController _town = TextEditingController();
  final TextEditingController _province = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().profile;
    _street.text = profile?.street ?? '';
    _barangay.text = profile?.barangay ?? '';
    _town.text = profile?.municipality ?? '';
    _province.text = profile?.province ?? '';
  }

  @override
  void dispose() {
    _street.dispose();
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
      street: _street.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const GreenPageHeader(
            title: 'Change Address',
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Your town decides which OSCA office handles your application.',
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
                _AddressField(
                  icon: Icons.signpost_outlined,
                  label: 'Purok / Street',
                  hint: 'e.g. Purok 7',
                  controller: _street,
                ),
                _AddressField(
                  icon: Icons.holiday_village_outlined,
                  label: 'Barangay',
                  hint: 'e.g. Poblacion',
                  controller: _barangay,
                ),
                _AddressField(
                  icon: Icons.location_city_outlined,
                  label: 'Town or city',
                  hint: 'e.g. Ubay',
                  controller: _town,
                  error: _error,
                ),
                _AddressField(
                  icon: Icons.map_outlined,
                  label: 'Province',
                  hint: 'e.g. Bohol',
                  controller: _province,
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
            label: _saving ? 'Saving...' : 'Save address',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}

/// One address part: a mint icon tile next to its label and text box.
class _AddressField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final String? error;

  const _AddressField({
    required this.icon,
    required this.label,
    required this.hint,
    required this.controller,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: IconTile(icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    hintText: hint,
                    errorText: error,
                    errorStyle: OnboardingScaffold.errorText,
                    errorMaxLines: 3,
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
