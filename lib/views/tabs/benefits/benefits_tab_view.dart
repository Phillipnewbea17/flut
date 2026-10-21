import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_state/accessibility_provider.dart';
import '../../../models/pension_record.dart';
import '../../../services/api_client.dart';
import '../../../services/pension_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/section_title.dart';
import '../../../widgets/status_pill.dart';

/// Benefits tab: the pension releases the OSCA office recorded for the
/// signed-in senior. The office keeps no amounts, so none are shown.
class BenefitsTabView extends StatefulWidget {
  const BenefitsTabView({super.key});

  @override
  State<BenefitsTabView> createState() => _BenefitsTabViewState();
}

class _BenefitsTabViewState extends State<BenefitsTabView> {
  /// Newest first, once the office has answered.
  List<PensionRecord>? _records;
  bool _failed = false;
  bool _notLinked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Asks the office for the releases. While it answers, the list already on
  /// the screen stays. A failure is shown as a failure, never as "no releases".
  Future<void> _load() async {
    final service = context.read<PensionService>();
    List<PensionRecord>? records;
    var notLinked = false;
    try {
      records = await service.fetchMine();
    } on ApiException catch (e) {
      // Not an error: the account has no senior record yet.
      notLinked = e.code == 'not_linked';
    } catch (_) {
      // Shown below as a failed load.
    }
    if (!mounted) return;
    setState(() {
      _records = records;
      _notLinked = notLinked;
      _failed = records == null && !notLinked;
    });
  }

  Widget _body() {
    if (_notLinked) {
      return const NoticeCard(
        icon: Icons.info_outline,
        text: 'Your pension records will show here once the OSCA office '
            'approves your application.',
      );
    }
    if (_failed) {
      return const NoticeCard(
        icon: Icons.error_outline,
        color: AppColors.warning,
        text: 'Could not load your pension records. Pull down to try again.',
      );
    }
    final records = _records;
    if (records == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return _Releases(records: records);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            TabHeader(
              title: context.tr('benefitsTitle'),
              subtitle: 'Your pension releases from the OSCA office.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('My pension'),
                  const SizedBox(height: 12),
                  _body(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The summary of the latest release, then one card per release.
class _Releases extends StatelessWidget {
  final List<PensionRecord> records;

  const _Releases({required this.records});

  @override
  Widget build(BuildContext context) {
    // The newest release the office has marked as released, if any.
    PensionRecord? latest;
    for (final record in records) {
      if (record.isReleased) {
        latest = record;
        break;
      }
    }
    final date = DateFormat('MMMM d, y');
    String summary;
    if (latest == null) {
      summary = 'No pension released yet';
    } else if (latest.releaseDate == null) {
      summary = 'Last received: ${latest.period}';
    } else {
      summary = 'Last received: ${date.format(latest.releaseDate!)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoCard(
          outlined: true,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                latest == null ? Icons.schedule : Icons.check_circle,
                color: latest == null
                    ? AppColors.textSecondary
                    : AppColors.success,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          const Text(
            'The OSCA office has not recorded any pension releases for you yet.',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReleaseCard(record: record),
          ),
      ],
    );
  }
}

/// One release: its period, status, and what the office wrote down.
class _ReleaseCard extends StatelessWidget {
  final PensionRecord record;

  const _ReleaseCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMMM d, y');
    return InfoCard(
      outlined: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.period,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(StatusLook.pension(record)),
          ),
          const SizedBox(height: 12),
          if (record.isReleased && record.releaseDate != null)
            _Detail('Released on ${date.format(record.releaseDate!)}'),
          if (record.receivedBy.isNotEmpty)
            _Detail('Received by: ${record.receivedBy}'),
          if (record.reference.isNotEmpty)
            _Detail('Reference: ${record.reference}'),
          if (record.remarks.isNotEmpty) _Detail('Remarks: ${record.remarks}'),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String text;

  const _Detail(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }
}
