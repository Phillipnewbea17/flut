import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/announcement.dart';
import '../theme/app_colors.dart';

/// One announcement from the OSCA office (Home and Announcements):
/// a mint band with the date and title, and the message under it.
class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback? onTap;
  final double? width;
  final bool showFullText;

  /// Shows a "Read more" link under the text (Home).
  final bool showReadMore;

  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onTap,
    this.width = 300,
    this.showFullText = false,
    this.showReadMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final date = announcement.date;
    // "October 20, 2026 · 9:15 PM": when it was posted, in Philippine time.
    final posted =
        DateFormat('MMMM d, y · h:mm a').format(announcement.postedAt);
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFCDEBD9), Color(0xFFE9F6EE)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        label: DateFormat('MMMM d, y').format(date),
                        excludeSemantics: true,
                        child: Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('MMM').format(date).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '${date.day}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.campaign,
                          color: AppColors.primary, size: 28),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showFullText) ...[
                        Text(
                          posted,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        announcement.body,
                        maxLines: showFullText ? null : 3,
                        overflow: showFullText
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (showReadMore) ...[
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Read more',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.primary, size: 22),
                          ],
                        ),
                      ],
                    ],
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
