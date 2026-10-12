import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/senior_id.dart';
import '../theme/app_colors.dart';
import 'status_pill.dart';

/// The digital Senior Citizen ID card (My ID).
/// When [seniorId] is null the card says the ID is not ready yet.
class SeniorIdCard extends StatelessWidget {
  final SeniorId? seniorId;
  final String fallbackName;

  /// The ID photo from the office. It needs the sign-in token, so the page
  /// passes it in (see WalletRepository.idPhoto); null hides the photo.
  final ImageProvider? photo;

  const SeniorIdCard({
    super.key,
    required this.seniorId,
    this.fallbackName = '',
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final id = seniorId;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: AppColors.heroGradient,
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
          // A soft ring in the corner, like a printed card pattern.
          Positioned(
            right: -90,
            bottom: -110,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x12FFFFFF), width: 30),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: id == null ? _pending() : _issued(id),
          ),
        ],
      ),
    );
  }

  Widget _top(String right) {
    return Row(
      children: [
        const Icon(Icons.eco, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'SENIOR CITIZEN ID',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Flexible: with big text it wraps instead of running off the card.
        Flexible(
          child: Text(
            right,
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _pending() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _top('Not issued yet'),
        const SizedBox(height: 22),
        Text(
          fallbackName.isEmpty ? 'Your ID' : fallbackName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your digital ID will appear here when your application '
                'is approved.',
                style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _issued(SeniorId id) {
    final dateFormat = DateFormat('MMM d, y');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _top(id.issuedBy),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photo != null) ...[
              _Photo(image: photo!),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    id.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatusBadge(status: id.status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _field('ID number', id.idNumber, big: true),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _field('Birthday', dateFormat.format(id.birthDate))),
            Expanded(child: _field('Issued', dateFormat.format(id.issuedAt))),
          ],
        ),
        if (id.address.isNotEmpty) ...[
          const SizedBox(height: 10),
          _field('Address', id.address),
        ],
      ],
    );
  }

  Widget _field(String label, String value, {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xCCFFFFFF),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: big ? 18 : 15,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: big ? 1.5 : 0,
          ),
        ),
      ],
    );
  }
}

/// "Valid", "For replacement"... on the card: white pill, icon and words.
class _StatusBadge extends StatelessWidget {
  final SeniorIdStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final look = StatusLook.seniorId(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(look.icon, color: look.color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              look.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
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

/// The ID photo from the OSCA office (needs internet).
class _Photo extends StatelessWidget {
  final ImageProvider image;

  const _Photo({required this.image});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 96,
        color: const Color(0x2EFFFFFF),
        child: Image(
          image: image,
          fit: BoxFit.cover,
          semanticLabel: 'ID photo',
          errorBuilder: (context, error, stack) =>
              const Icon(Icons.person, color: Colors.white, size: 44),
        ),
      ),
    );
  }
}
