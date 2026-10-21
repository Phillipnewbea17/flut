import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../app_state/user_provider.dart';
import '../../../models/announcement.dart';
import '../../../models/application_status.dart';
import '../../../models/user_profile.dart';
import '../../../repositories/application_repository.dart';
import '../../../routes/app_router.dart';
import '../../../services/announcements_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/announcement_card.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/profile_avatar.dart';
import '../../../widgets/section_title.dart';
import '../../../widgets/status_pill.dart';

/// Home tab. Answers, from top to bottom:
///   1. What is happening with my application?  (Application Status)
///   2. What can I do now?                      (Quick actions)
///   3. What does the OSCA office want me to know? (Latest announcement)
class HomeDashboardView extends StatefulWidget {
  const HomeDashboardView({super.key});

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  late Future<List<Announcement>> _announcements;

  @override
  void initState() {
    super.initState();
    _announcements = context.read<AnnouncementsService>().fetchAnnouncements();
  }

  Future<void> _refresh() async {
    final applications = context.read<ApplicationRepository>();
    setState(() {
      _announcements = context.read<AnnouncementsService>().fetchAnnouncements();
    });
    await Future.wait<void>([
      applications.load(),
      _announcements.then((_) {}, onError: (_) {}),
    ]);
  }

  String _greeting(BuildContext context, String firstName) {
    if (firstName.isEmpty) return 'Mabuhay!';
    final hour = DateTime.now().hour;
    final key = hour < 12
        ? 'homeGoodMorning'
        : hour < 18
            ? 'homeGoodAfternoon'
            : 'homeGoodEvening';
    return context.tr(key, {'name': firstName});
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final applications = context.watch<ApplicationRepository>();
    final topInset = MediaQuery.paddingOf(context).top;
    final profile = user.profile;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120), // room for SOS button
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A. HEADER: avatar, greeting, bell, then the address chip
              Padding(
                padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _AvatarButton(
                          profile: profile,
                          onTap: () => context.go(Routes.account),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMMM d')
                                    .format(DateTime.now()),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              Semantics(
                                header: true,
                                child: Text(
                                  _greeting(context, user.firstName),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _BellButton(
                          unread: applications.unreadCount,
                          onTap: () => context.push(Routes.notifications),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LocationButton(
                      text: (profile?.hasAddress ?? false)
                          ? profile!.shortAddress
                          : context.tr('homeAddAddress'),
                      onTap: () => context.push(Routes.address),
                    ),
                  ],
                ),
              ),

              // B. APPLICATION STATUS (green hero card)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _ApplicationStatusCard(status: applications.status),
              ),
              if (applications.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          applications.error!,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // C. QUICK ACTIONS
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(context.tr('homeQuickActions'), fontSize: 20),
                    const SizedBox(height: 16),
                    _TileRow(
                      left: _QuickTile(
                        icon: Icons.upload_file_outlined,
                        title: context.tr('tileUpload'),
                        subtitle: context.tr('tileUploadSub'),
                        highlight: true,
                        onTap: () => context.push(Routes.upload),
                      ),
                      right: _QuickTile(
                        icon: Icons.volunteer_activism_outlined,
                        title: context.tr('tileAssistance'),
                        subtitle: context.tr('tileAssistanceSub'),
                        onTap: () => context.push(Routes.assistance),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TileRow(
                      left: _QuickTile(
                        icon: Icons.forum_outlined,
                        title: context.tr('tileHelp'),
                        subtitle: context.tr('tileHelpSub'),
                        onTap: () => context.push(Routes.help),
                      ),
                      right: _QuickTile(
                        icon: Icons.badge_outlined,
                        title: context.tr('tileIdServices'),
                        subtitle: context.tr('tileIdServicesSub'),
                        onTap: () => context.push(Routes.idServices),
                      ),
                    ),

                    // D. LATEST ANNOUNCEMENT
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: SectionTitle(
                            context.tr('homeLatestAnnouncement'),
                            fontSize: 20,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.announcements),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('homeViewAll'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.primary, size: 22),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LatestAnnouncements(future: _announcements),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The senior's address as a white chip under the greeting.
class _LocationButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LocationButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bell with the number of unread messages, on a white rounded square.
class _BellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _BellButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread new',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none,
                      color: AppColors.textPrimary, size: 24),
                  if (unread > 0)
                    Positioned(
                      top: 4,
                      right: 2,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 20, minHeight: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The profile photo once the senior has set one (Personal information),
/// otherwise a person icon.
class _AvatarButton extends StatelessWidget {
  final UserProfile? profile;
  final VoidCallback onTap;

  const _AvatarButton({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open my account',
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppColors.cardShadow,
        ),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 52,
              height: 52,
              child: profile?.photoPath == null
                  ? const Icon(Icons.person_outline,
                      color: AppColors.primary, size: 28)
                  : Padding(
                      padding: const EdgeInsets.all(2),
                      child: ProfileAvatar(profile: profile, radius: 24),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short summary of the application on the green hero card, with one
/// clear button. The full details (steps, history, papers) are on the
/// Application Status page.
class _ApplicationStatusCard extends StatelessWidget {
  final ApplicationStatus status;

  const _ApplicationStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final stage = status.stage;
    final updatedAt = status.updatedAt;

    final String buttonLabel;
    final IconData buttonIcon;
    final String route;
    switch (stage) {
      case ApplicationStage.notStarted:
      case ApplicationStage.cancelled:
        buttonLabel = 'Start application';
        buttonIcon = Icons.upload_file_outlined;
        route = Routes.upload;
      case ApplicationStage.needsAction:
        buttonLabel = 'View what needs fixing';
        buttonIcon = Icons.build_outlined;
        route = Routes.applicationStatus;
      case ApplicationStage.approved:
      case ApplicationStage.rejected:
        buttonLabel = 'View details';
        buttonIcon = Icons.chevron_right;
        route = Routes.applicationStatus;
      case ApplicationStage.submitted:
      case ApplicationStage.review:
        buttonLabel = 'View status';
        buttonIcon = Icons.chevron_right;
        route = Routes.applicationStatus;
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x660C6E3D),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft rings in the corner, like the mockup.
          Positioned(
            right: -70,
            top: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x12FFFFFF), width: 28),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -60,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0FFFFFFF),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    stage.wasSent && status.applicationNo.isNotEmpty
                        ? '${context.tr('homeApplicationStatus')} · '
                            '#${status.applicationNo}'
                        : context.tr('homeApplicationStatus'),
                    style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (!stage.wasSent) ...[
                  Text(
                    stage == ApplicationStage.cancelled
                        ? 'Your application was cancelled. You can start again any time.'
                        : 'You have not submitted an application yet.',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send photos of your papers to apply for your Senior Citizen ID.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xE6FFFFFF),
                      height: 1.4,
                    ),
                  ),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _HeroChip(
                      look: StatusLook.application(context, stage),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    status.message,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  if (updatedAt != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Last update: ${DateFormat('MMMM d, y, h:mm a').format(updatedAt)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xD9FFFFFF),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 18),
                _HeroButton(
                  label: buttonLabel,
                  icon: buttonIcon,
                  trailingIcon: buttonIcon == Icons.chevron_right,
                  onPressed: () => context.push(route),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The status ("Being checked", "Approved"...) as a see-through chip on
/// the green hero card. Icon and words, never color alone.
class _HeroChip extends StatelessWidget {
  final StatusLook look;

  const _HeroChip({required this.look});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(look.icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              look.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White button with green words, for the green hero card.
class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool trailingIcon;
  final VoidCallback onPressed;

  const _HeroButton({
    required this.label,
    required this.icon,
    required this.trailingIcon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: AppColors.primary, size: 22);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!trailingIcon) ...[iconWidget, const SizedBox(width: 10)],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailingIcon) ...[const SizedBox(width: 6), iconWidget],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The newest one or two announcements from the OSCA office.
class _LatestAnnouncements extends StatelessWidget {
  final Future<List<Announcement>> future;

  const _LatestAnnouncements({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Announcement>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final items = snapshot.data ?? const <Announcement>[];
        if (snapshot.hasError || items.isEmpty) {
          return const Text(
            'No announcements right now. Pull down to refresh.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items.take(2)) ...[
              AnnouncementCard(
                announcement: item,
                width: null,
                showReadMore: true,
                onTap: () => context.push(Routes.announcements),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _TileRow extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TileRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight makes both tiles in a row the same height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The first tile has a filled green icon, like the mockup.
  final bool highlight;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InfoCard(
        outlined: true,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: highlight ? AppColors.primary : AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: highlight ? Colors.white : AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
