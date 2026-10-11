import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/service_request.dart';
import '../../../repositories/wallet_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/choice_option.dart';
import '../../shared/request_wizard.dart';

/// "Request a new ID": reason -> details -> photos -> review.
/// Staff handle it in the web's Senior ID Management, where they replace
/// the ID (the web's "request replacement" and "replace" actions).
class IdReplacementView extends StatefulWidget {
  const IdReplacementView({super.key});

  /// (what the senior sees, the web's SeniorId::REPLACEMENT_REASONS value)
  static const List<(String, String)> reasons = [
    ('Lost', 'Lost'),
    ('Damaged', 'Damaged'),
    ('Incorrect information', 'Incorrect Information'),
    ('Other', 'Other'),
  ];

  @override
  State<IdReplacementView> createState() => _IdReplacementViewState();
}

class _IdReplacementViewState extends State<IdReplacementView> {
  final _detailsController = TextEditingController();
  (String, String)? _reason;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String get _detailsLabel {
    switch (_reason?.$2) {
      case 'Lost':
        return 'When and where did you lose it? (optional)';
      case 'Damaged':
        return 'What happened to it? (optional)';
      case 'Incorrect Information':
        return 'What is wrong, and what should it say?';
      default:
        return 'Please explain';
    }
  }

  bool get _detailsRequired =>
      _reason?.$2 == 'Incorrect Information' || _reason?.$2 == 'Other';

  @override
  Widget build(BuildContext context) {
    final id = context.watch<WalletRepository>().seniorId;
    if (id == null) {
      return Scaffold(
        appBar: AppTheme.appBar('ID replacement'),
        body: const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'You do not have a Senior Citizen ID yet, so there is nothing to '
            'replace. Your ID will appear in "My ID" when your application '
            'is approved.',
            style: TextStyle(fontSize: 20, color: AppColors.textPrimary, height: 1.4),
          ),
        ),
      );
    }

    return RequestWizard(
      title: 'ID replacement',
      kind: RequestKind.idReplacement,
      photosHint: 'a photo of the damaged ID, or an affidavit of loss',
      buildDraft: () => RequestDraft(
        title: 'Replace ID: ${_reason?.$1 ?? ''}',
        details: [
          RequestDetail('ID number', id.idNumber),
          RequestDetail('Reason', _reason?.$1 ?? ''),
          RequestDetail('Details', _detailsController.text.trim()),
        ],
        payload: {
          'idNumber': id.idNumber,
          'reason': _reason?.$2 ?? '',
          'details': _detailsController.text.trim(),
        },
      ),
      steps: [
        WizardStep(
          title: 'Why do you need a new ID?',
          validate: () => _reason == null ? 'Please choose one.' : null,
          builder: (context) => Column(
            children: [
              for (final reason in IdReplacementView.reasons)
                ChoiceOption(
                  text: reason.$1,
                  selected: _reason == reason,
                  onTap: () => setState(() => _reason = reason),
                ),
            ],
          ),
        ),
        WizardStep(
          title: 'Tell us more',
          validate: () =>
              _detailsRequired && _detailsController.text.trim().length < 5
                  ? 'Please explain a little more.'
                  : null,
          builder: (context) => WizardTextField(
            label: _detailsLabel,
            controller: _detailsController,
            maxLines: 6,
          ),
        ),
      ],
    );
  }
}
