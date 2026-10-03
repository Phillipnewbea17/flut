import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/senior_id.dart';
import '../theme/app_colors.dart';

/// The digital Senior Citizen ID card in My Wallet.
/// When [seniorId] is null the card says the ID is not ready yet.
class SeniorIdCard extends StatelessWidget {
  final SeniorId? seniorId;
  final String fallbackName;

  const SeniorIdCard({
    super.key,
    required this.seniorId,
    this.fallbackName = '',
  });

  @override
  Widget build(BuildContext context) {
    final id = seniorId;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primaryBright],
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: id == null ? _pending() : _issued(id),
    );
  }

  Widget _top(String right) {
    return Row(
      children: [
        const Icon(Icons.favorite, color: Colors.white, size: 26),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'SENIOR CITIZEN ID',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          right,
          style: const TextStyle(color: Colors.white, fontSize: 15),
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
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your digital ID will appear here when your application '
                'is approved.',
                style: TextStyle(color: Colors.white, fontSize: 18, height: 1.4),
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
        Text(
          id.fullName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
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
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: big ? 24 : 18,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: big ? 1.5 : 0,
          ),
        ),
      ],
    );
  }
}
