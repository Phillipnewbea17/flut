import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/announcement.dart';
import '../../../services/announcements_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/announcement_card.dart';
import '../../../widgets/big_button.dart';

/// "View all" announcements.
class AnnouncementsView extends StatefulWidget {
  const AnnouncementsView({super.key});

  @override
  State<AnnouncementsView> createState() => _AnnouncementsViewState();
}

class _AnnouncementsViewState extends State<AnnouncementsView> {
  late Future<List<Announcement>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AnnouncementsService>().fetchAnnouncements();
  }

  Future<void> _reload() async {
    final future = context.read<AnnouncementsService>().fetchAnnouncements();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // The error message is shown by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTheme.appBar('Announcements'),
      body: FutureBuilder<List<Announcement>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load announcements. Please check your internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  BigButton(
                    label: 'Try again',
                    icon: Icons.refresh,
                    onPressed: _reload,
                  ),
                ],
              ),
            );
          }
          final items = snapshot.data ?? const <Announcement>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: items.isEmpty ? 1 : items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                if (items.isEmpty) {
                  return const Text(
                    'No announcements right now.',
                    style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  );
                }
                return AnnouncementCard(
                  announcement: items[index],
                  width: null,
                  showFullText: true,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
