import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/application_status.dart';
import '../../../repositories/application_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/info_card.dart';

/// Which messages the list shows.
enum _Filter { all, unread, last7, last30 }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.unread => 'Unread',
        _Filter.last7 => 'Last 7 days',
        _Filter.last30 => 'Last 30 days',
      };

  String get emptyText => switch (this) {
        _Filter.all => 'No notifications yet.',
        _Filter.unread => 'No unread notifications.',
        _Filter.last7 => 'No notifications in the last 7 days.',
        _Filter.last30 => 'No notifications in the last 30 days.',
      };

  bool keeps(AppNotification n, DateTime now) => switch (this) {
        _Filter.all => true,
        _Filter.unread => !n.read,
        _Filter.last7 => now.difference(n.date).inDays < 7,
        _Filter.last30 => now.difference(n.date).inDays < 30,
      };
}

/// The bell: messages about the application and from the OSCA office.
///
/// Everything (read marks, deletes, clear all) goes through the shared
/// ApplicationRepository, so the bell badge on Home updates at once.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  _Filter _filter = _Filter.all;

  Future<void> _open(AppNotification item) async {
    // Opening a message clears its NEW mark (and the bell count).
    context.read<ApplicationRepository>().markRead(item.id);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title, style: const TextStyle(fontSize: 22)),
        content: SingleChildScrollView(
          child: Text(
            '${item.body}\n\n${_dateText(item.date)}',
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _delete(AppNotification item) {
    final repo = context.read<ApplicationRepository>();
    repo.hide(item.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Notification deleted',
            style: TextStyle(fontSize: 18)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => repo.unhide(item.id),
        ),
      ));
  }

  Future<void> _clearAll() async {
    final repo = context.read<ApplicationRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?',
            style: TextStyle(fontSize: 22)),
        content: const Text(
          'All notifications will be removed from this list.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Clear all',
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
    if (confirmed == true) await repo.hideAll();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ApplicationRepository>();
    final now = DateTime.now();
    // Newest first (the repository sorts them).
    final items =
        repo.notifications.where((n) => _filter.keeps(n, now)).toList();

    return Scaffold(
      appBar: AppTheme.appBar('Notifications', actions: [
        _MoreMenu(
          canMarkRead: repo.unreadCount > 0,
          canClear: repo.notifications.isNotEmpty,
          onMarkAllRead: repo.markAllRead,
          onClearAll: _clearAll,
        ),
      ]),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterChips(
            selected: _filter,
            onSelected: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: repo.load,
              child: items.isEmpty
                  ? _EmptyState(text: _filter.emptyText)
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        for (final group in _groups(items, now)) ...[
                          _GroupHeader(group.$1),
                          for (final item in group.$2)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _SwipeToDelete(
                                id: item.id,
                                onDelete: () => _delete(item),
                                child: _NotificationTile(
                                  item: item,
                                  onTap: () => _open(item),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Today / Yesterday / Earlier, keeping the newest-first order.
  static List<(String, List<AppNotification>)> _groups(
      List<AppNotification> items, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final groups = <String, List<AppNotification>>{};
    for (final n in items) {
      final day = DateTime(n.date.year, n.date.month, n.date.day);
      final name = !day.isBefore(today)
          ? 'Today'
          : !day.isBefore(yesterday)
              ? 'Yesterday'
              : 'Earlier';
      (groups[name] ??= []).add(n);
    }
    return [
      for (final name in const ['Today', 'Yesterday', 'Earlier'])
        if (groups[name] != null) (name, groups[name]!),
    ];
  }
}

String _dateText(DateTime date) => DateFormat('MMM d, y  h:mm a').format(date);

/// All / Unread / Last 7 days / Last 30 days, in one scrollable row.
class _FilterChips extends StatelessWidget {
  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          for (final f in _Filter.values) ...[
            ChoiceChip(
              label: Text(f.label),
              selected: f == selected,
              onSelected: (_) => onSelected(f),
              showCheckmark: false,
              materialTapTargetSize: MaterialTapTargetSize.padded,
              labelStyle: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: f == selected ? Colors.white : AppColors.primary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String text;
  const _GroupHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Swipe left to delete (the list hides it; "Undo" brings it back).
class _SwipeToDelete extends StatelessWidget {
  final String id;
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeToDelete({
    required this.id,
    required this.onDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('notification-$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// ⋮ menu: Mark all as read, Clear all.
class _MoreMenu extends StatelessWidget {
  final bool canMarkRead;
  final bool canClear;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClearAll;

  const _MoreMenu({
    required this.canMarkRead,
    required this.canClear,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => v == 'read' ? onMarkAllRead() : onClearAll(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'read',
          enabled: canMarkRead,
          height: 56,
          child: const Text('Mark all as read', style: TextStyle(fontSize: 18)),
        ),
        PopupMenuItem(
          value: 'clear',
          enabled: canClear,
          height: 56,
          child: const Text('Clear all', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const Icon(Icons.notifications_none,
            size: 64, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isNew = !item.read;
    return Semantics(
      button: true,
      label: '${isNew ? 'New. ' : ''}${item.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: InfoCard(
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
                        if (isNew) const _NewBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _dateText(item.date),
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
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}
