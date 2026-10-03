import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../app_state/user_provider.dart';
import '../../../models/document_item.dart';
import '../../../models/purchase_booklet.dart';
import '../../../repositories/document_repository.dart';
import '../../../repositories/wallet_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../../widgets/senior_id_card.dart';
import 'document_preview_sheet.dart';

/// My Wallet tab: digital Senior ID, purchase booklet, saved papers.
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletRepository>();
    final documents = context.watch<DocumentRepository>();
    final user = context.watch<UserProvider>();
    final topInset = MediaQuery.paddingOf(context).top;
    final booklet = wallet.booklet;
    final now = DateTime.now();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        onRefresh: wallet.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            GreenHeaderStack(
              overlap: 110,
              header: Padding(
                padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        context.tr('walletTitle'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your ID, discounts and papers in one place.',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
              card: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SeniorIdCard(
                  seniorId: wallet.seniorId,
                  fallbackName: user.profile?.fullName ?? '',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wallet.hasSeniorId)
                    BigButton(
                      label: context.tr('walletShowCashier'),
                      icon: Icons.qr_code_2,
                      onPressed: () => context.push(Routes.qrCashier),
                    ),
                  const SizedBox(height: 28),
                  _Heading(context.tr('walletBooklet')),
                  const SizedBox(height: 12),
                  InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'You saved this month',
                          style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPeso(booklet.savedInMonth(now)),
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          'Total saved: ${formatPeso(booklet.totalSaved)}',
                          style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        BigButton(
                          label: 'Add a purchase',
                          icon: Icons.add,
                          style: BigButtonStyle.tonal,
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            showDragHandle: true,
                            backgroundColor: Colors.white,
                            builder: (sheetContext) => const _AddPurchaseSheet(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (booklet.entries.isEmpty)
                    const Text(
                      'Write down what you buy with your senior discount, '
                      'like the paper purchase booklet.',
                      style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                    )
                  else
                    for (final entry in booklet.entries.take(20))
                      _PurchaseTile(entry: entry),
                  const SizedBox(height: 28),
                  _Heading(context.tr('walletDocuments')),
                  const SizedBox(height: 12),
                  if (documents.documents.isEmpty)
                    const Text(
                      'Photos of your papers will be kept here, safe on this phone.',
                      style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                    )
                  else
                    for (final doc in documents.documents) _DocumentTile(item: doc),
                  const SizedBox(height: 12),
                  BigButton(
                    label: 'Upload documents',
                    icon: Icons.upload_file_outlined,
                    style: BigButtonStyle.tonal,
                    onPressed: () => context.push(Routes.upload),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final PurchaseEntry entry;
  const _PurchaseTile({required this.entry});

  Future<void> _confirmDelete(BuildContext context) async {
    final wallet = context.read<WalletRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this purchase?', style: TextStyle(fontSize: 24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await wallet.removePurchase(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        outlined: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.item.isEmpty ? entry.category.label : entry.item,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${entry.store}  •  ${DateFormat('MMM d').format(entry.date)}',
                    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  Text(
                    'Paid ${formatPeso(entry.amountPaid)}, saved ${formatPeso(entry.saved)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              iconSize: 26,
              onPressed: () => _confirmDelete(context),
              icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DocumentItem item;
  const _DocumentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final sent = item.isUploaded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoCard(
        outlined: true,
        padding: const EdgeInsets.all(12),
        onTap: () => showDocumentPreviewSheet(context, item),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Image.file(
                  File(item.filePath),
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  errorBuilder: (context, error, stackTrace) => const ColoredBox(
                    color: AppColors.primaryLight,
                    child: Icon(Icons.description_outlined, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.type.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    sent ? 'Sent' : 'Not sent yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sent ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 28),
          ],
        ),
      ),
    );
  }
}

class _AddPurchaseSheet extends StatefulWidget {
  const _AddPurchaseSheet();

  @override
  State<_AddPurchaseSheet> createState() => _AddPurchaseSheetState();
}

class _AddPurchaseSheetState extends State<_AddPurchaseSheet> {
  final TextEditingController _storeController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  PurchaseCategory _category = PurchaseCategory.medicine;
  String? _error;

  @override
  void dispose() {
    _storeController.dispose();
    _itemController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = _storeController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0;
    if (store.isEmpty) {
      setState(() => _error = 'Please enter the store name.');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Please enter the price.');
      return;
    }
    final result = SeniorDiscount.compute(price, _category);
    final navigator = Navigator.of(context);
    await context.read<WalletRepository>().addPurchase(
          PurchaseEntry(
            id: 'buy-${DateTime.now().millisecondsSinceEpoch}',
            date: DateTime.now(),
            store: store,
            item: _itemController.text.trim(),
            category: _category,
            price: result.price,
            amountPaid: result.amountToPay,
          ),
        );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(_priceController.text) ?? 0;
    final result = SeniorDiscount.compute(price, _category);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add a purchase',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in PurchaseCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: c == _category,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c == _category ? Colors.white : AppColors.primary,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.primaryLight,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Store', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 6),
          TextField(
            controller: _storeController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 19),
            decoration: const InputDecoration(hintText: 'e.g. Town Pharmacy'),
          ),
          const SizedBox(height: 14),
          const Text('What did you buy? (optional)', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 6),
          TextField(
            controller: _itemController,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 19),
            decoration: const InputDecoration(hintText: 'e.g. Maintenance medicine'),
          ),
          const SizedBox(height: 14),
          const Text('Price on the tag', style: OnboardingScaffold.fieldLabel),
          const SizedBox(height: 6),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}\.?\d{0,2}')),
            ],
            onChanged: (_) => setState(() => _error = null),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(prefixText: '₱ ', hintText: '0.00'),
          ),
          const SizedBox(height: 12),
          if (price > 0)
            Text(
              'You should pay ${formatPeso(result.amountToPay)} '
              '(you save ${formatPeso(result.saved)}).',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: OnboardingScaffold.errorText),
          ],
          const SizedBox(height: 20),
          BigButton(label: 'Save', icon: Icons.save_outlined, onPressed: _save),
        ],
      ),
    );
  }
}
