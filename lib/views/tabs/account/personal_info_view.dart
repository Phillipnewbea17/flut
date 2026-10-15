import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/user_provider.dart';
import '../../../models/personal_info.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/identity_repository.dart';
import '../../../routes/app_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/green_page_header.dart';
import '../../../widgets/icon_tile.dart';
import '../../../widgets/pill_button.dart';
import '../../../widgets/profile_avatar.dart';
import 'profile_photo_sheet.dart';

final DateFormat _longDate = DateFormat('MMMM dd, y');

/// Personal information: a green header with the profile photo, "Change
/// Photo" and the name, then one row per detail.
///
/// Once the Senior ID is issued (the account is linked to its SCMS record),
/// the name, birthday, sex, civil status and ID number come from that
/// record and are locked: only the OSCA office can change them. Before that
/// the page shows what the senior entered. The photo and the address can
/// always be changed.
class PersonalInfoView extends StatefulWidget {
  const PersonalInfoView({super.key});

  @override
  State<PersonalInfoView> createState() => _PersonalInfoViewState();
}

class _PersonalInfoViewState extends State<PersonalInfoView> {
  @override
  void initState() {
    super.initState();
    // A Senior ID issued since the app opened shows up right away.
    context.read<IdentityRepository>().refreshFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final profile = user.profile ??
        const UserProfile(phone: '', fullName: '', role: UserRole.senior);
    final linked = context.watch<IdentityRepository>().profile;

    // The official record behind the Senior ID, once it is issued.
    final official = linked != null && linked.isVerified ? linked.info : null;
    final hasId = official != null;

    final name = hasId && official.fullName.isNotEmpty
        ? official.fullName
        : profile.fullName;
    final birthDate = official?.birthDate ?? profile.birthDate;
    // Before the ID: the sex the senior sent with the application, if any.
    final sex = (official ?? linked?.info)?.sex?.label ?? '';

    // The address the senior set themselves, or - while they have not set
    // one - what the OSCA office keeps on their record. A senior citizen
    // record only holds the purok, so that is usually all this shows.
    // Change Address still overrides it.
    final ownAddress = profile.addressLine;
    final address =
        ownAddress.isNotEmpty ? ownAddress : (official?.fullAddress ?? '');

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          GreenPageHeader(
            title: 'Personal Information',
            child: _PhotoAndName(profile: profile, name: name),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasId) const _FromIdNote(),
                if (hasId && official.seniorId.isNotEmpty)
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'Senior ID number',
                    value: official.seniorId,
                    locked: true,
                  ),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date of birth',
                  value: birthDate == null ? '' : _longDate.format(birthDate),
                  locked: hasId,
                ),
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'Age',
                  value: birthDate == null
                      ? ''
                      : '${UserProfile.ageOn(birthDate, DateTime.now())} years old',
                  locked: hasId,
                ),
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Sex (Gender)',
                  value: sex,
                  locked: hasId,
                ),
                if (hasId)
                  _InfoRow(
                    icon: Icons.favorite_border,
                    label: 'Civil status',
                    value: official.civilStatus?.label ?? '',
                    locked: true,
                  ),
                // The address the account signs in with. Only the OSCA
                // office can move an account to another one, so it is shown
                // locked here.
                _InfoRow(
                  icon: Icons.mail_outline,
                  label: 'Email address',
                  value: profile.email,
                  locked: true,
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone number',
                  value: profile.phone.isEmpty ? '' : '+63${profile.phone}',
                  below: Align(
                    alignment: Alignment.centerLeft,
                    child: PillButton(
                      label: profile.phone.isEmpty
                          ? 'Add Phone Number'
                          : 'Change Phone Number',
                      tonal: true,
                      onPressed: () => context.push(Routes.phoneNumber),
                    ),
                  ),
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Current Address',
                  value: address.toUpperCase(),
                  last: true,
                  below: Align(
                    alignment: Alignment.centerLeft,
                    child: PillButton(
                      label: 'Change Address',
                      tonal: true,
                      onPressed: () => context.push(Routes.address),
                    ),
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

/// "From your Senior ID": the locked rows are the OSCA office's record.
class _FromIdNote extends StatelessWidget {
  const _FromIdNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, color: AppColors.primary, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'These details are from your Senior ID. To correct them, '
              'please visit the OSCA office.',
              style: TextStyle(
                  fontSize: 15, color: AppColors.textPrimary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Small widgets
// =============================================================================

/// The photo with a white ring, "Change Photo" and the name in capitals.
class _PhotoAndName extends StatelessWidget {
  final UserProfile profile;
  final String name;

  const _PhotoAndName({required this.profile, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Change profile photo',
          child: GestureDetector(
            onTap: () => changeProfilePhoto(context),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ProfileAvatar(profile: profile, radius: 56),
            ),
          ),
        ),
        const SizedBox(height: 14),
        PillButton(
          label: 'Change Photo',
          onPressed: () => changeProfilePhoto(context),
        ),
        const SizedBox(height: 14),
        Text(
          name.isEmpty ? 'YOUR NAME' : name.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// One detail: a mint icon tile, a small label and the value in bold, with
/// a thin line under it. [locked] rows (from the Senior ID) get a lock.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? below;
  final bool last;
  final bool locked;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.below,
    this.last = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.trim().isEmpty;
    final shown = empty ? (locked ? 'Not on record' : 'Not set yet') : value;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE3ECE7), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: '$label, $shown${locked ? ', from your Senior ID' : ''}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 15, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        shown,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
                          fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                          color: empty
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (below != null) ...[
                  const SizedBox(height: 14),
                  below!,
                ],
              ],
            ),
          ),
          if (locked)
            const Padding(
              padding: EdgeInsets.only(left: 8, top: 14),
              child: Icon(Icons.lock_outline,
                  size: 20, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
