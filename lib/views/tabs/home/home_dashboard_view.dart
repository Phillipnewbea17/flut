import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../app_state/user_provider.dart';
import '../../../models/application_status.dart';
import '../../../models/benefit.dart';
import '../../../repositories/application_repository.dart';
import '../../../routes/app_router.dart';
import '../../../services/benefits_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/onboarding_scaffold.dart';
import '../../../widgets/status_stepper.dart';

/// Home tab: greeting, application status, quick actions, announcements.
class HomeDashboardView extends StatefulWidget {
  /// Opens the Account tab (the round avatar in the header).
  final VoidCallback onOpenAccount;

  const HomeDashboardView({super.key, required this.onOpenAccount});

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  late Future<List<Announcement>> _announcements;

  @override
  void initState() {
    super.initState();
    _announcements = context.read<BenefitsService>().fetchAnnouncements();
  }

  Future<void> _refresh() async {
    final applications = context.read<ApplicationRepository>();
    setState(() {
      _announcements = context.read<BenefitsService>().fetchAnnouncements();
    });
    await Future.wait<void>([
      applications.load(),
      _announcements.then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final applications = context.watch<ApplicationRepository>();
    final topInset = MediaQuery.paddingOf(context).top;
    final profile = user.profile;
    final firstName = user.firstName;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
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
              GreenHeaderStack(
                overlap: 96,
                header: Padding(
                  padding: EdgeInsets.fromLTRB(24, topInset + 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _LocationButton(
                              text: (profile?.hasAddress ?? false)
                                  ? profile!.shortAddress
                                  : context.tr('homeAddAddress'),
                              onTap: () => context.push(Routes.address),
                            ),
                          ),
                          _BellButton(
                            unread: applications.unreadCount,
                            onTap: () => context.push(Routes.notifications),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    firstName.isEmpty
                                        ? 'Mabuhay!'
                                        : context.tr(
                                      'homeGreeting',
                                      {'name': firstName},
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('EEE, MMM d, y')
                                      .format(DateTime.now()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _AvatarButton(onTap: widget.onOpenAccount),
                        ],
                      ),
                    ],
                  ),
                ),
                card: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ApplicationCard(
                    status: applications.status,
                    onViewProgress: () => context.push(Routes.progress),
                    onStart: () => context.push(Routes.upload),
                  ),
                ),
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
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle(context.tr('homeQuickActions')),
                    const SizedBox(height: 16),
                    _TileRow(
                      left: _QuickTile(
                        icon: Icons.calculate_outlined,
                        title: context.tr('tileCalculator'),
                        subtitle: context.tr('tileCalculatorSub'),
                        onTap: () => context.push(Routes.calculator),
                      ),
                      right: _QuickTile(
                        icon: Icons.upload_file_outlined,
                        title: context.tr('tileUpload'),
                        subtitle: context.tr('tileUploadSub'),
                        onTap: () => context.push(Routes.upload),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TileRow(
                      left: _QuickTile(
                        icon: Icons.group_outlined,
                        title: context.tr('tileFamily'),
                        subtitle: context.tr('tileFamilySub'),
                        onTap: () => context.push(Routes.family),
                      ),
                      right: _QuickTile(
                        icon: Icons.favorite_outline,
                        title: context.tr('tileBenefits'),
                        subtitle: context.tr('tileBenefitsSub'),
                        onTap: () => context.push(Routes.benefits),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: _SectionTitle(
                            context.tr('homeLatestAnnouncements'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(Routes.announcements),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text(
                            context.tr('homeViewAll'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              FutureBuilder<List<Announcement>>(
                future: _announcements,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snapshot.data ?? const <Announcement>[];
                  if (snapshot.hasError || items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No announcements right now. Pull down to refresh.',
                        style: TextStyle(
                          fontSize: 17,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in items.take(5)) ...[
                            AnnouncementCard(
                              announcement: item,
                              onTap: () => context.push(Routes.announcements),
                            ),
                            const SizedBox(width: 14),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LocationButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined,
                  color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _BellButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: unread == 0
          ? 'Notifications'
          : 'Notifications, $unread new',
      child: Material(
        color: const Color(0x33FFFFFF),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.notifications_none,
                    color: Colors.white, size: 32),
                if (unread > 0)
                  Positioned(
                    top: 12,
                    right: 13,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
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

class _AvatarButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AvatarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open my account',
      child: Material(
        color: AppColors.primaryLight,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white, width: 4),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 84,
            height: 84,
            child: Icon(Icons.person_outline,
                color: AppColors.primary, size: 42),
          ),
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ApplicationStatus status;
  final VoidCallback onViewProgress;

  /// Opens Upload documents (shown while the application is not sent yet).
  final VoidCallback onStart;

  const _ApplicationCard({
    required this.status,
    required this.onViewProgress,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (status.stage) {
      ApplicationStage.notStarted => AppColors.textSecondary,
      ApplicationStage.needsAction => AppColors.warning,
      _ => AppColors.success,
    };

    return InfoCard(
      padding: const EdgeInsets.fromLTRB(22, 14, 10, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: small label on the left, "View progress >" on the right.
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('homeYourApplication'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _ViewProgressLink(onTap: onViewProgress),
            ],
          ),
          const SizedBox(height: 2),

          // Row 2: the status gets the full width, on one line, so a word
          // like "Submitted" is never split. Long translations shrink a
          // little instead of wrapping.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr(status.stage.labelKey),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: StatusStepper(stage: status.stage),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              status.message,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          if (status.stage.canSubmit) ...[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: BigButton(
                label: status.stage == ApplicationStage.notStarted
                    ? 'Start my application'
                    : 'Fix my papers',
                icon: Icons.upload_file_outlined,
                onPressed: onStart,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "View progress >" in one line, pushed to the right edge of the card.
class _ViewProgressLink extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewProgressLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          // At least 48 x 48 so it is easy to tap.
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('homeViewProgress'),
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InfoCard(
        outlined: true,
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 17,
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

/// Small announcement card (Home carousel). Also used in AnnouncementsView.
class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback? onTap;
  final double? width;
  final bool showFullText;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.width = 300,
    this.showFullText = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InfoCard(
        outlined: true,
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.campaign_outlined,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM d, y').format(announcement.date),
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              announcement.title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              announcement.body,
              maxLines: showFullText ? null : 3,
              overflow:
              showFullText ? TextOverflow.visible : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}