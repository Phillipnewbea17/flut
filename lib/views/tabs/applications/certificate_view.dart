import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../models/assistance_certificate.dart';
import '../../../repositories/requests_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/section_title.dart';

/// The Certificate of Eligibility of an approved Medical or Burial
/// request. The senior shows this screen (or a printed copy) with a valid ID
/// at the OSCA office. Staff check the code, or scan the QR code, and mark it
/// claimed: it works only once. It names no amount.
class CertificateView extends StatelessWidget {
  /// The request's id on this phone, or its reference number.
  final String id;

  const CertificateView({super.key, required this.id});

  static final DateFormat _date = DateFormat('MMMM d, y');

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RequestsRepository>();
    final certificate = repo.find(id)?.certificate;

    return Scaffold(
      appBar: AppTheme.appBar('Your certificate'),
      body: RefreshIndicator(
        onRefresh: repo.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: certificate == null
              ? const [
                  NoticeCard(
                    icon: Icons.hourglass_top,
                    title: 'No certificate yet',
                    text: 'The OSCA office has not approved this request yet. '
                        'Pull down to check again.',
                  ),
                ]
              : [
                  _Sheet(certificate: certificate, date: _date),
                  const SizedBox(height: 20),
                  certificate.isClaimed
                      ? NoticeCard(
                          icon: Icons.check_circle,
                          color: AppColors.success,
                          title: 'Already claimed',
                          text: 'Claimed on '
                              '${_date.format(certificate.claimedAt!)}'
                              '${certificate.receivedBy.isEmpty ? '' : ' by ${certificate.receivedBy}'}'
                              '. This certificate cannot be used again.',
                        )
                      : const NoticeCard(
                          icon: Icons.info_outline,
                          title: 'How to claim',
                          text: 'Bring this certificate (on this phone or '
                              'printed) and a valid ID to the OSCA office. The '
                              'staff will check the code below. You can claim '
                              'it only once.',
                        ),
                ],
        ),
      ),
    );
  }
}

/// The certificate itself, laid out like the printed one.
class _Sheet extends StatelessWidget {
  final AssistanceCertificate certificate;
  final DateFormat date;

  const _Sheet({required this.certificate, required this.date});

  @override
  Widget build(BuildContext context) {
    final c = certificate;
    final ids = [
      if (c.seniorNumber.isNotEmpty) 'Senior citizen no. ${c.seniorNumber}',
      if (c.oscaIdNumber.isNotEmpty) 'OSCA ID ${c.oscaIdNumber}',
    ].join(' · ');
    const lead = TextStyle(fontSize: 17, color: AppColors.textSecondary);

    return Semantics(
      container: true,
      label: 'Certificate of Eligibility ${c.number}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 3),
        ),
        child: Column(
          children: [
            const Text(
              'Office of Senior Citizens Affairs (OSCA)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'CERTIFICATE OF ELIGIBILITY',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Text('No. ${c.number}',
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Text(
              c.claimantName.isEmpty
                  ? 'This certifies that'
                  : 'This certifies that the family of the late',
              textAlign: TextAlign.center,
              style: lead,
            ),
            const SizedBox(height: 4),
            Text(
              c.seniorName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (ids.isNotEmpty)
              Text(ids,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Text(
              c.claimantName.isEmpty
                  ? 'is eligible to receive'
                  : 'through ${c.claimantName}, is eligible to receive',
              textAlign: TextAlign.center,
              style: lead,
            ),
            const SizedBox(height: 4),
            Text(
              c.program.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            if (c.issuedAt != null) ...[
              const SizedBox(height: 14),
              Text(
                'Approved on ${date.format(c.issuedAt!)}'
                '${c.issuedBy.isEmpty ? '' : ' by ${c.issuedBy}'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ],
            const SizedBox(height: 20),
            if (c.isClaimed)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.danger, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'CLAIMED',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                    letterSpacing: 2,
                  ),
                ),
              ),
            Opacity(
              opacity: c.isClaimed ? 0.35 : 1,
              child: QrImageView(
                data: c.code,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                semanticsLabel: 'QR code of the verification code',
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              c.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              'Verification code',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
