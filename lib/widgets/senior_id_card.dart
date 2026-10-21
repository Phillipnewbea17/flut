import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/senior_id.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The digital Senior Citizen ID card (My ID).
///
/// Once the office has issued the ID, the card is drawn like the OSCA card
/// the web prints (scms-frontend, Senior IDs > Print card): the same layout,
/// colors, field labels and order, the same ID number format, and the 2x2
/// photo at the top right. The card keeps the printed card's proportions
/// (85.6 x 54 mm) at any phone width: every size is a share of the card
/// width, the web's "cqw" unit.
///
/// When [seniorId] is null the card says the ID is not ready yet.
class SeniorIdCard extends StatelessWidget {
  final SeniorId? seniorId;
  final String fallbackName;

  /// The 2x2 photo the office holds (WalletRepository.idPhoto), or null. The
  /// card then shows the senior's initials, as the web does.
  final Uint8List? photo;

  const SeniorIdCard({
    super.key,
    required this.seniorId,
    this.fallbackName = '',
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final id = seniorId;
    if (id != null) return _OscaIdCard(id: id, photo: photo);

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
            child: _pending(),
          ),
        ],
      ),
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
}

/// The card's own words and colors, as on the printed card (SeniorIds.jsx).
const String _locality = 'Los Angeles, Ubay, Bohol';
const String _logo = 'assets/illustrations/scms-logo.png';
const Color _paper = Color(0xFFFBFCFD);
const Color _edge = Color(0xFFCDD5D0);
const Color _ink = Color(0xFF1B1F23);
const Color _headline = Color(0xFF222222);
const Color _blue = Color(0xFF2A7BC0);
const Color _red = Color(0xFFC8323B);
const Color _photoPaper = Color(0xFFEEF1F2);
const Color _photoEdge = Color(0xFF9AA6A0);
const Color _photoInk = Color(0xFF8A959C);

/// Text for the card: Arial-like weight and size scaled to the card width.
/// The app's font family is kept; [size] is already in logical pixels.
TextStyle _text(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = _ink,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.15,
      letterSpacing: letterSpacing,
    );

/// "MM/DD/YYYY", as printed on OSCA cards, or a dash when unknown.
String _cardDate(DateTime? date) =>
    date == null ? '—' : DateFormat('MM/dd/yyyy').format(date);

/// "F" or "M" as the card prints it, or a dash when not recorded.
String _sexLetter(String sex) {
  if (RegExp(r'^f', caseSensitive: false).hasMatch(sex)) return 'F';
  if (RegExp(r'^m', caseSensitive: false).hasMatch(sex)) return 'M';
  return '—';
}

/// "JUAN DELA CRUZ" becomes "JD", as the photo box shows without a photo.
String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w[0]).join().toUpperCase();
  return letters.isEmpty ? '?' : letters;
}

/// The OSCA card, laid out in the web's proportions. Every number below is a
/// percentage of the card width ([u] is 1% of it).
class _OscaIdCard extends StatelessWidget {
  final SeniorId id;
  final Uint8List? photo;

  const _OscaIdCard({required this.id, required this.photo});

  /// The word printed across a card that is not valid, so it cannot pass as
  /// an active one (none for an active card).
  static String? _stamp(SeniorIdStatus status) => switch (status) {
        SeniorIdStatus.pendingIssuance => 'Pending issuance',
        SeniorIdStatus.forReplacement => 'For replacement',
        SeniorIdStatus.inactive => 'Inactive',
        SeniorIdStatus.active => null,
      };

  @override
  Widget build(BuildContext context) {
    final stamp = _stamp(id.status);
    final birth = id.birthDate;
    // The age printed is the age on the day of issue (today, until issued).
    final age = birth == null
        ? id.age
        : UserProfile.ageOn(birth, id.issuedAt ?? DateTime.now());
    final purok = id.purok.trim();
    final address = purok.isEmpty ? _locality : '$purok, $_locality';

    return Semantics(
      label: 'OSCA ID card ${id.idNumber} for ${id.fullName}'
          '${stamp == null ? '' : ', ${stamp.toLowerCase()}'}',
      excludeSemantics: true,
      child: MediaQuery(
        // The card has its own sizes; the text size setting does not apply.
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: AspectRatio(
          aspectRatio: 85.6 / 54,
          child: LayoutBuilder(
            builder: (context, box) {
              final u = box.maxWidth / 100;
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _paper,
                  border: Border.all(color: _edge),
                  borderRadius: BorderRadius.circular(2.2 * u),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E10231A),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // The seal, faint, behind the text (the web's watermark).
                    Positioned.fill(
                      child: Align(
                        alignment: const Alignment(-0.08, 0.04),
                        child: Opacity(
                          opacity: 0.08,
                          child: Image.asset(_logo, width: 30 * u),
                        ),
                      ),
                    ),
                    // Seal and the office names.
                    Positioned(
                      top: 3.5 * u,
                      left: 4 * u,
                      right: 30 * u,
                      child: Row(
                        children: [
                          Image.asset(
                            _logo,
                            width: 15 * u,
                            height: 15 * u,
                            fit: BoxFit.contain,
                          ),
                          SizedBox(width: 2.5 * u),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Republic of the Philippines',
                                    textAlign: TextAlign.center,
                                    style: _text(2.5 * u,
                                        weight: FontWeight.w700,
                                        color: _headline),
                                  ),
                                  Text(
                                    'Province of Bohol',
                                    textAlign: TextAlign.center,
                                    style: _text(2.5 * u,
                                        weight: FontWeight.w700,
                                        color: _headline),
                                  ),
                                  Text(
                                    'Office of Senior Citizens Affairs',
                                    textAlign: TextAlign.center,
                                    style: _text(2.75 * u,
                                        weight: FontWeight.w700, color: _blue),
                                  ),
                                  Text(
                                    'MUNICIPALITY OF UBAY',
                                    textAlign: TextAlign.center,
                                    style: _text(3.1 * u,
                                        weight: FontWeight.w800,
                                        color: _red,
                                        letterSpacing: 0.02 * 3.1 * u),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The 2x2 photo, top right.
                    Positioned(
                      top: 3.5 * u,
                      right: 3.5 * u,
                      width: 24 * u,
                      height: 27 * u,
                      child: _PhotoBox(photo: photo, name: id.fullName, u: u),
                    ),
                    // Name and address, kept clear of the photo.
                    Positioned(
                      top: 24 * u,
                      left: 5 * u,
                      right: 4 * u,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: 27 * u),
                            child: _Line(
                              label: 'Name :',
                              value: id.fullName,
                              u: u,
                              long: 22,
                              veryLong: 30,
                            ),
                          ),
                          SizedBox(height: 1.2 * u),
                          _Line(
                            label: 'Address:',
                            value: address,
                            u: u,
                            long: 30,
                            veryLong: 40,
                          ),
                        ],
                      ),
                    ),
                    // Birth date, age, sex and date of issue.
                    Positioned(
                      top: 35.5 * u,
                      left: 3 * u,
                      right: 3 * u,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 14,
                            child: _Fact(
                              label: 'Date of Birth',
                              value: _cardDate(birth),
                              u: u,
                            ),
                          ),
                          Expanded(
                            flex: 8,
                            child: _Fact(
                              label: 'Age',
                              value: age?.toString() ?? '—',
                              u: u,
                            ),
                          ),
                          Expanded(
                            flex: 8,
                            child: _Fact(
                              label: 'Sex',
                              value: _sexLetter(id.sex),
                              u: u,
                            ),
                          ),
                          Expanded(
                            flex: 14,
                            child: _Fact(
                              label: 'Date of Issue',
                              value: _cardDate(id.issuedAt),
                              u: u,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ID number, and the signature line with the name.
                    Positioned(
                      top: 48 * u,
                      left: 5 * u,
                      right: 4 * u,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ID No. ${id.idNumber}',
                            maxLines: 1,
                            softWrap: false,
                            style: _text(3.4 * u,
                                weight: FontWeight.w800, color: _red),
                          ),
                          SizedBox(width: 3 * u),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 0.25 * u,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 0.5 * u),
                                  child: Text(
                                    id.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _text(3.2 * u,
                                        weight: FontWeight.w700),
                                  ),
                                ),
                                SizedBox(height: 0.5 * u),
                                Text(
                                  'Printed Name and Signature/Thumbmark',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _text(2.3 * u),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // The fine print across the bottom.
                    Positioned(
                      left: 3 * u,
                      right: 3 * u,
                      bottom: 2.2 * u,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'THIS CARD IS NON-TRANSFERABLE AND VALID ANYWHERE IN '
                          'THE COUNTRY',
                          maxLines: 1,
                          softWrap: false,
                          style: _text(2.05 * u,
                              weight: FontWeight.w800, color: _blue),
                        ),
                      ),
                    ),
                    if (stamp != null)
                      Align(
                        alignment: const Alignment(0, -0.08),
                        child: Transform.rotate(
                          angle: -14 * math.pi / 180,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 3 * u,
                              vertical: 0.8 * u,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.7),
                              border: Border.all(
                                color: _red,
                                width: 0.6 * u,
                              ),
                              borderRadius: BorderRadius.circular(1 * u),
                            ),
                            child: Text(
                              stamp.toUpperCase(),
                              maxLines: 1,
                              softWrap: false,
                              style: _text(5 * u,
                                  weight: FontWeight.w900,
                                  color: _red,
                                  letterSpacing: 0.06 * 5 * u),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The 2x2 photo box: the office's photo, or the initials until there is one.
class _PhotoBox extends StatelessWidget {
  final Uint8List? photo;
  final String name;
  final double u;

  const _PhotoBox({required this.photo, required this.name, required this.u});

  @override
  Widget build(BuildContext context) {
    final placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _initials(name),
          style: _text(7 * u, weight: FontWeight.w700, color: _photoInk),
        ),
        SizedBox(height: 0.6 * u),
        Text(
          'PHOTO',
          style: _text(2.2 * u,
              color: _photoInk, letterSpacing: 0.08 * 2.2 * u),
        ),
      ],
    );
    final bytes = photo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _photoPaper,
        border: Border.all(color: _photoEdge),
      ),
      child: bytes == null
          ? placeholder
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: 'ID photo',
              errorBuilder: (context, error, stack) => placeholder,
            ),
    );
  }
}

/// "Name :" and "Address:" lines. A long value gets a smaller size so it
/// stays on one line, as the web does.
class _Line extends StatelessWidget {
  final String label;
  final String value;
  final double u;
  final int long;
  final int veryLong;

  const _Line({
    required this.label,
    required this.value,
    required this.u,
    required this.long,
    required this.veryLong,
  });

  @override
  Widget build(BuildContext context) {
    final size = value.length > veryLong
        ? 2.7
        : value.length > long
            ? 3.2
            : 3.9;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: _text(3 * u, weight: FontWeight.w700)),
        SizedBox(width: 1.6 * u),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(size * u, weight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// One figure in the row under the address: the value, then its label.
class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final double u;

  const _Fact({required this.label, required this.value, required this.u});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: _text(4.4 * u, weight: FontWeight.w700),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: _text(2.6 * u),
        ),
      ],
    );
  }
}
