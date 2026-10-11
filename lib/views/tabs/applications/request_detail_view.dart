import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/service_request.dart';
import '../../../repositories/requests_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/big_button.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/section_title.dart';
import '../../../widgets/status_pill.dart';

/// One request: status, the office's latest answer, what was sent.
/// Only what the senior should see; staff assignment and internal remarks
/// stay in the web app.
class RequestDetailView extends StatefulWidget {
  final String id;

  /// Opened right after submitting: says whether it reached the office.
  final bool justSent;

  const RequestDetailView({super.key, required this.id, this.justSent = false});

  @override
  State<RequestDetailView> createState() => _RequestDetailViewState();
}

class _RequestDetailViewState extends State<RequestDetailView> {
  static final DateFormat _date = DateFormat('MMMM d, y');
  static final DateFormat _dateTime = DateFormat('MMMM d, y, h:mm a');
  bool _sending = false;

  Future<void> _send(ServiceRequest request) async {
    setState(() => _sending = true);
    final result = await context.read<RequestsRepository>().send(request);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSent
              ? 'Sent. Your reference number is ${result.reference}.'
              : (result.sendError ?? 'Not sent. Please try again.'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Future<void> _delete(ServiceRequest request) async {
    final repo = context.read<RequestsRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this request?', style: TextStyle(fontSize: 24)),
        content: const Text(
          'It was not sent, so the OSCA office does not have it. It will be '
          'removed from this phone.',
          style: TextStyle(fontSize: 18, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
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
    if (confirmed != true || !mounted) return;
    await repo.removeDraft(request);
    if (mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RequestsRepository>();
    final request = repo.find(widget.id);

    if (request == null) {
      return Scaffold(
        appBar: AppTheme.appBar('Request'),
        body: const Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'This request is no longer on this phone.',
            style: TextStyle(fontSize: 20, color: AppColors.textPrimary),
          ),
        ),
      );
    }

    final available = repo.isAvailable(request.kind);

    return Scaffold(
      appBar: AppTheme.appBar(request.kind.title),
      body: RefreshIndicator(
        onRefresh: repo.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            if (widget.justSent) ...[
              _ResultBanner(request: request),
              const SizedBox(height: 20),
            ],
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    request.reference.isEmpty
                        ? 'No reference number yet'
                        : 'Reference: ${request.reference}',
                    style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  StatusPill(StatusLook.request(request), large: true),
                  const SizedBox(height: 16),
                  _Line(
                    label: request.isSent ? 'Submitted' : 'Saved on this phone',
                    value: _date.format(request.submittedAt ?? request.createdAt),
                  ),
                  if (request.updatedAt != null)
                    _Line(
                      label: 'Last update',
                      value: _dateTime.format(request.updatedAt!),
                    ),
                ],
              ),
            ),
            if (request.latestResponse.isNotEmpty) ...[
              const SizedBox(height: 20),
              NoticeCard(
                icon: Icons.forum_outlined,
                title: 'Latest response from the OSCA office',
                text: request.latestResponse,
              ),
            ],
            if (!request.isSent) ...[
              const SizedBox(height: 20),
              if (available) ...[
                if (request.sendError != null) ...[
                  Text(
                    request.sendError!,
                    style: const TextStyle(fontSize: 17, color: AppColors.danger),
                  ),
                  const SizedBox(height: 10),
                ],
                BigButton(
                  label: _sending ? 'Sending...' : 'Send now',
                  icon: Icons.send_outlined,
                  onPressed: _sending ? null : () => _send(request),
                ),
              ] else
                NoticeCard.notConnected(
                  text: 'This request is saved on this phone only. The '
                      'OSCA office did NOT receive it. Please visit or call '
                      'the OSCA office. It can be sent from here once the '
                      'service is connected.',
                ),
              const SizedBox(height: 12),
              BigButton(
                label: 'Delete this request',
                icon: Icons.delete_outline,
                style: BigButtonStyle.tonal,
                onPressed: _sending ? null : () => _delete(request),
              ),
            ],
            if (request.history.isNotEmpty) ...[
              const SizedBox(height: 28),
              const SectionTitle('What happened so far', fontSize: 22),
              const SizedBox(height: 12),
              for (final event in request.history.reversed)
                _HistoryTile(event: event, format: _dateTime),
            ],
            const SizedBox(height: 28),
            const SectionTitle('What you sent', fontSize: 22),
            const SizedBox(height: 12),
            InfoCard(
              outlined: true,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in request.details)
                    if (d.value.isNotEmpty) ...[
                      Text(
                        d.label,
                        style: const TextStyle(
                            fontSize: 16, color: AppColors.textSecondary),
                      ),
                      Text(
                        d.value,
                        style: const TextStyle(
                          fontSize: 19,
                          color: AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  if (request.attachments.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final path in request.attachments)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(path),
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (context, error, stack) =>
                                  const SizedBox(
                                width: 88,
                                height: 88,
                                child: ColoredBox(
                                  color: AppColors.primaryLight,
                                  child: Icon(Icons.image_outlined,
                                      color: AppColors.primary),
                                ),
                              ),
                            ),
                          ),
                      ],
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

/// "Sent! Reference ..." or "Saved on this phone, NOT sent".
class _ResultBanner extends StatelessWidget {
  final ServiceRequest request;

  const _ResultBanner({required this.request});

  @override
  Widget build(BuildContext context) {
    if (request.isSent) {
      return NoticeCard(
        icon: Icons.check_circle,
        color: AppColors.success,
        title: 'Request sent',
        text: 'The OSCA office received your request. Your reference number '
            'is ${request.reference}. You will see their answer here.',
      );
    }
    return NoticeCard(
      icon: Icons.cloud_off_outlined,
      color: AppColors.danger,
      title: 'Saved, but NOT sent',
      text: request.sendError ?? 'Your request was not sent.',
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final RequestEvent event;
  final DateFormat format;

  const _HistoryTile({required this.event, required this.format});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.note,
                  style: const TextStyle(
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                Text(
                  format.format(event.date),
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
