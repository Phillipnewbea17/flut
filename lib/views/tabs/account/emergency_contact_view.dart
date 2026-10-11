import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/emergency_contact.dart';
import '../../../services/sos_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/emergency_contact_form.dart';
import '../../../widgets/green_page_header.dart';

/// The people the SOS button calls, in order: who is called first, then the
/// backups. Changes are kept on this page until "Save changes".
class EmergencyContactView extends StatefulWidget {
  const EmergencyContactView({super.key});

  @override
  State<EmergencyContactView> createState() => _EmergencyContactViewState();
}

class _EmergencyContactViewState extends State<EmergencyContactView> {
  static const int _maxContacts = 5;

  late List<EmergencyContact> _contacts;
  late List<EmergencyContact> _saved;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saved = context.read<UserProvider>().emergencyContacts;
    _contacts = List.of(_saved);
  }

  bool get _dirty {
    if (_contacts.length != _saved.length) return true;
    for (var i = 0; i < _contacts.length; i++) {
      if (_contacts[i].encode() != _saved[i].encode()) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final user = context.read<UserProvider>();
    final sos = context.read<SosService>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    await user.saveEmergencyContacts(_contacts);
    // Ask for the phone and location permissions now, not during an SOS.
    if (_contacts.isNotEmpty) await sos.prepare();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = List.of(_contacts);
    });
    messenger.showSnackBar(const SnackBar(
      content: Text('Emergency contacts saved.', style: TextStyle(fontSize: 18)),
    ));
    if (router.canPop()) router.pop();
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?', style: TextStyle(fontSize: 22)),
        content: const Text(
          'You changed your emergency contacts but did not save them.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('KEEP EDITING',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DISCARD',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _contacts = List.of(_saved));
      context.pop();
    }
  }

  /// Add (index null) or edit one contact in a sheet.
  Future<void> _openContact([int? index]) async {
    final user = context.read<UserProvider>();
    final current = index == null ? null : _contacts[index];
    final taken = {
      for (var i = 0; i < _contacts.length; i++)
        if (i != index) _contacts[i].phone,
    };

    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                current == null ? 'Add a contact' : 'Edit contact',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              EmergencyContactForm(
                initial: current,
                ownPhone: user.profile?.phone,
                takenPhones: taken,
                submitLabel: current == null ? 'Add contact' : 'Done',
                submitIcon: current == null ? Icons.add : Icons.check,
                onSubmit: (contact) async =>
                    Navigator.of(sheetContext).pop(_SheetResult.saved(contact)),
              ),
              if (index != null && index > 0) ...[
                const SizedBox(height: 12),
                BigButton(
                  label: 'Call this person first',
                  icon: Icons.vertical_align_top,
                  style: BigButtonStyle.tonal,
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(const _SheetResult.first()),
                ),
              ],
              if (index != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(const _SheetResult.remove()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(48, 56),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove from list',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      switch (result) {
        case _SheetResult(:final contact?):
          if (index == null) {
            _contacts.add(contact);
          } else {
            _contacts[index] = contact;
          }
        case _SheetResult(moveFirst: true):
          _contacts.insert(0, _contacts.removeAt(index!));
        case _SheetResult(remove: true):
          _contacts.removeAt(index!);
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const GreenPageHeader(
              title: 'Emergency Contacts',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'When you press SOS, we call these people in order.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.white, fontSize: 17, height: 1.4),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Who should we call in an emergency?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(
                        child: _FeatureChip(
                          icon: Icons.timer_outlined,
                          text: '5-second cancel timer',
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _FeatureChip(
                          icon: Icons.sms_outlined,
                          text: 'Location sent by SMS',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  for (var i = 0; i < _contacts.length; i++)
                    _TimelineStep(
                      marker: _NumberMarker(i + 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ContactCard(
                            contact: _contacts[i],
                            tag: i == 0
                                ? 'CALLS FIRST'
                                : i == 1
                                    ? 'CALLS NEXT'
                                    : 'BACKUP ${i - 1}',
                            onEdit: () => _openContact(i),
                          ),
                          if (i == 0 && _contacts.length > 1)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                              child: Text(
                                'No answer? Your SOS screen shows the next '
                                'person to call.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_contacts.length < _maxContacts)
                    _TimelineStep(
                      marker: const _AddMarker(),
                      child: _AddButton(
                        label: _contacts.isEmpty
                            ? 'Add a contact'
                            : 'Add backup contact',
                        onPressed: () => _openContact(),
                      ),
                    ),
                  const _TimelineStep(
                    marker: _CallMarker(),
                    last: true,
                    child: _Call911Card(),
                  ),
                  const SizedBox(height: 24),
                  BigButton(
                    label: _saving ? 'Saving...' : 'Save changes',
                    icon: Icons.save_outlined,
                    onPressed: _saving || !_dirty ? null : _save,
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

/// What the edit sheet asked for.
class _SheetResult {
  final EmergencyContact? contact;
  final bool moveFirst;
  final bool remove;

  const _SheetResult.saved(EmergencyContact this.contact)
      : moveFirst = false,
        remove = false;
  const _SheetResult.first()
      : contact = null,
        moveFirst = true,
        remove = false;
  const _SheetResult.remove()
      : contact = null,
        moveFirst = false,
        remove = true;
}

// =============================================================================
// Small widgets
// =============================================================================

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One step of the call order: a marker on a green line, then [child].
class _TimelineStep extends StatelessWidget {
  final Widget marker;
  final Widget child;
  final bool last;

  const _TimelineStep({
    required this.marker,
    required this.child,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 10),
                marker,
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberMarker extends StatelessWidget {
  final int number;
  const _NumberMarker(this.number);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddMarker extends StatelessWidget {
  const _AddMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: const Icon(Icons.add, color: AppColors.primary, size: 24),
    );
  }
}

class _CallMarker extends StatelessWidget {
  const _CallMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.call_outlined, color: Colors.white, size: 22),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final String tag;
  final VoidCallback onEdit;

  const _ContactCard({
    required this.contact,
    required this.tag,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (contact.relationship.trim().isNotEmpty) contact.relationship.trim(),
      '+63 ${contact.displayPhone}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Edit ${contact.name}',
            excludeSemantics: true,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onEdit();
                },
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.edit_note,
                      color: AppColors.primary, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _AddButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(
          side: BorderSide(color: AppColors.primary, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Center(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Call911Card extends StatelessWidget {
  const _Call911Card();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Still need help? Call ${SosService.nationalEmergency}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'The red ${SosService.nationalEmergency} button is always on '
            'your SOS screen.',
            style: TextStyle(
                fontSize: 15, color: AppColors.textPrimary, height: 1.35),
          ),
        ],
      ),
    );
  }
}
