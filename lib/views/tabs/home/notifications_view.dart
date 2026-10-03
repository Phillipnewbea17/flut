import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/application_status.dart';
import '../../../repositories/application_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// The bell: messages about the application and from the OSCA office.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  /// Ids that were new when this screen opened, so they stay highlighted
  /// while the user reads them.
  late final Set<String> _newIds;

  @override
  void initState() {
    super.initState();
    final repo = context.read<ApplicationRepository>();
    _newIds = repo.notifications.where((n) => !n.read).map((n) => n.id).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) repo.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ApplicationRepository>();
    final items = repo.notifications;

    return Scaffold(
      appBar: AppTheme.appBar('Notifications'),
      body: RefreshIndicator(
        onRefresh: repo.load,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                children: const [
                  Icon(Icons.notifications_none,
                      size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'No messages yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _NotificationTile(
                  item: items[index],
                  isNew: _newIds.contains(items[index].id),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool isNew;

  const _NotificationTile({required this.item, required this.isNew});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      outlined: !isNew,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMM d, y  h:mm a').format(item.date),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
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
