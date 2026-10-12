import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../repositories/wallet_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/status_pill.dart';

/// Everything printed on the Senior ID, in big text.
class IdDetailsView extends StatefulWidget {
  const IdDetailsView({super.key});

  @override
  State<IdDetailsView> createState() => _IdDetailsViewState();
}

class _IdDetailsViewState extends State<IdDetailsView> {
  @override
  void initState() {
    super.initState();
    // Reachable straight from ID services, so ask the office again here too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<WalletRepository>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = context.watch<WalletRepository>().seniorId;
    final date = DateFormat('MMMM d, y');

    return Scaffold(
      appBar: AppTheme.appBar('ID details'),
      body: id == null
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Your Senior Citizen ID is not ready yet. It will appear '
                'when your application is approved.',
                style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row('Status', child: StatusPill(StatusLook.seniorId(id.status))),
                      _Row('Name', value: id.fullName),
                      _Row('OSCA / Senior ID number', value: id.idNumber, selectable: true),
                      if (id.recordNo.isNotEmpty)
                        _Row('Record number', value: id.recordNo, selectable: true),
                      _Row('Birthday', value: date.format(id.birthDate)),
                      if (id.age != null) _Row('Age', value: '${id.age} years old'),
                      if (id.sex.isNotEmpty) _Row('Sex', value: id.sex),
                      if (id.address.isNotEmpty) _Row('Address', value: id.address),
                      _Row('Issued by', value: id.issuedBy),
                      _Row('Date issued', value: date.format(id.issuedAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Is something wrong? Use "ID replacement" and choose '
                  '"Incorrect information".',
                  style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final bool selectable;

  const _Row(this.label, {this.value, this.child, this.selectable = false});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          child ??
              (selectable
                  ? SelectableText(value ?? '', style: style)
                  : Text(value ?? '', style: style)),
        ],
      ),
    );
  }
}
