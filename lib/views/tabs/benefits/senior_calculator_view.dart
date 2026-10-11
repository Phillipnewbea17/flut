import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/purchase_booklet.dart';
import '../../../models/user_profile.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';

/// "Senior calculator": am I old enough, and how much is my discount?
class SeniorCalculatorView extends StatelessWidget {
  const SeniorCalculatorView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppTheme.appBar(
          'Senior calculator',
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xCCFFFFFF),
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            labelStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontSize: 19),
            tabs: [
              Tab(height: 56, text: 'Eligibility'),
              Tab(height: 56, text: 'Discount'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_EligibilityTab(), _DiscountTab()],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Eligibility
// -----------------------------------------------------------------------------

class _EligibilityTab extends StatefulWidget {
  const _EligibilityTab();

  @override
  State<_EligibilityTab> createState() => _EligibilityTabState();
}

class _EligibilityTabState extends State<_EligibilityTab>
    with AutomaticKeepAliveClientMixin {
  DateTime? _birthDate;

  static const List<int> _cashGiftAges = [80, 85, 90, 95, 100];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _birthDate = context.read<UserProvider>().profile?.birthDate;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 60, now.month, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Choose your birthday',
      initialEntryMode: DatePickerEntryMode.input,
      fieldHintText: 'mm/dd/yyyy',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _saveBirthday() async {
    final birthDate = _birthDate;
    final user = context.read<UserProvider>();
    final profile = user.profile;
    if (birthDate == null || profile == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await user.updateProfile(profile.copyWith(birthDate: birthDate));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Birthday saved.', style: TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profile = context.watch<UserProvider>().profile;
    final birthDate = _birthDate;
    final dateFormat = DateFormat('MMMM d, y');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'When is your birthday?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Filipinos aged 60 and above can get a Senior Citizen ID.',
          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        BigButton(
          label: birthDate == null
              ? 'Choose birthday'
              : dateFormat.format(birthDate),
          icon: Icons.cake_outlined,
          style: BigButtonStyle.tonal,
          onPressed: _pickDate,
        ),
        if (birthDate != null) ...[
          const SizedBox(height: 20),
          _EligibilityResult(birthDate: birthDate),
          if (profile != null && profile.birthDate != birthDate) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _saveBirthday,
              style: TextButton.styleFrom(minimumSize: const Size(48, 52)),
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'Save as my birthday',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _CashGiftNote(birthDate: birthDate, ages: _cashGiftAges),
        ],
      ],
    );
  }
}

class _EligibilityResult extends StatelessWidget {
  final DateTime birthDate;

  const _EligibilityResult({required this.birthDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final age = UserProfile.ageOn(birthDate, now);
    final eligible = age >= 60;
    final turns60 = DateTime(birthDate.year + 60, birthDate.month, birthDate.day);

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are $age years old.',
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                eligible ? Icons.check_circle : Icons.schedule,
                color: eligible ? AppColors.success : AppColors.warning,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eligible
                      ? 'You can apply for a Senior Citizen ID.'
                      : 'You can apply on '
                          '${DateFormat('MMMM d, y').format(turns60)}.',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          if (eligible) ...[
            const SizedBox(height: 20),
            BigButton(
              label: 'Upload documents',
              icon: Icons.upload_file_outlined,
              onPressed: () => context.push(Routes.upload),
            ),
          ],
        ],
      ),
    );
  }
}

class _CashGiftNote extends StatelessWidget {
  final DateTime birthDate;
  final List<int> ages;

  const _CashGiftNote({required this.birthDate, required this.ages});

  @override
  Widget build(BuildContext context) {
    final age = UserProfile.ageOn(birthDate, DateTime.now());
    int? next;
    for (final a in ages) {
      if (a > age) {
        next = a;
        break;
      }
    }
    if (next == null) return const SizedBox.shrink();
    final when = DateTime(birthDate.year + next, birthDate.month, birthDate.day);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.card_giftcard, color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'At age $next (${DateFormat('MMMM y').format(when)}) you can get '
            'a cash gift from the government. See Benefits & services.',
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Discount
// -----------------------------------------------------------------------------

class _DiscountTab extends StatefulWidget {
  const _DiscountTab();

  @override
  State<_DiscountTab> createState() => _DiscountTabState();
}

class _DiscountTabState extends State<_DiscountTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _priceController = TextEditingController();
  PurchaseCategory _category = PurchaseCategory.medicine;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final price = double.tryParse(_priceController.text) ?? 0;
    final result = SeniorDiscount.compute(price, _category);

    return ListView(
      padding: const EdgeInsets.all(20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const Text(
          'What are you buying?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in PurchaseCategory.values)
              ChoiceChip(
                label: Text(c.label),
                selected: c == _category,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c == _category ? Colors.white : AppColors.primary,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onSelected: (_) => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Price on the tag',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            prefixText: '₱ ',
            prefixStyle: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            hintText: '0.00',
          ),
        ),
        const SizedBox(height: 24),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Line(label: 'Price', value: formatPeso(result.price)),
              if (result.vatExempt)
                _Line(label: 'Less 12% VAT', value: '- ${formatPeso(result.vatRemoved)}'),
              _Line(
                label: 'Less ${(result.rate * 100).round()}% senior discount',
                value: '- ${formatPeso(result.discount)}',
              ),
              const Divider(height: 28, thickness: 2),
              _Line(
                label: 'You pay',
                value: formatPeso(result.amountToPay),
                big: true,
              ),
              const SizedBox(height: 8),
              Text(
                'You save ${formatPeso(result.saved)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _category == PurchaseCategory.groceries
              ? 'Basic groceries get 5% off. VAT is not removed, and weekly '
                  'limits apply.'
              : 'Bring your Senior Citizen ID. For medicines, bring your '
                  'purchase booklet and prescription too.',
          style: const TextStyle(
            fontSize: 17,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool big;

  const _Line({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: big ? 26 : 19,
      fontWeight: big ? FontWeight.w700 : FontWeight.w400,
      color: AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}
