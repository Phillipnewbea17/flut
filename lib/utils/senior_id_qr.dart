import 'dart:convert';

/// What was read from the QR code on a Senior Citizen ID.
///
/// Only [seniorId] is used, to look the record up in SCMS. [nameHint] is
/// whatever name the QR carried: it is NOT trusted, only sent along as the
/// user's claim so the backend can compare it with the record.
class ScannedSeniorId {
  final String seniorId;
  final String nameHint;

  const ScannedSeniorId(this.seniorId, {this.nameHint = ''});
}

class SeniorIdQr {
  SeniorIdQr._();

  /// Letters, numbers, "-" and "/", 4 to 30 long, with at least one number.
  static final RegExp _idPattern = RegExp(r'^[A-Z0-9][A-Z0-9\-/]{3,29}$');

  /// "uby-2026-00128 " -> "UBY-2026-00128"
  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static bool isValidId(String raw) {
    final id = normalize(raw);
    return _idPattern.hasMatch(id) && id.contains(RegExp(r'\d'));
  }

  /// Reads the formats a Senior Citizen ID QR may have:
  /// - "SCID|UBY-2026-00128|Rosela Mabuhay" (the app's own digital ID)
  /// - {"seniorId": "UBY-2026-00128", ...}
  /// - a link with ?id=, ?seniorId= or ?osca_id=
  /// - just the ID number
  /// Returns null for anything else (not a supported QR code).
  static ScannedSeniorId? parse(String? payload) {
    final text = (payload ?? '').trim();
    if (text.isEmpty) return null;

    if (text.toUpperCase().startsWith('SCID|')) {
      final parts = text.split('|');
      if (parts.length < 2 || !isValidId(parts[1])) return null;
      return ScannedSeniorId(
        normalize(parts[1]),
        nameHint: parts.length > 2 ? parts.sublist(2).join(' ').trim() : '',
      );
    }

    if (text.startsWith('{')) {
      try {
        final json = jsonDecode(text);
        if (json is Map) {
          final id = (json['seniorId'] ?? json['oscaId'] ?? json['idNumber'])
              ?.toString();
          if (id != null && isValidId(id)) {
            return ScannedSeniorId(
              normalize(id),
              nameHint: (json['fullName'] ?? json['name'] ?? '').toString(),
            );
          }
        }
      } on FormatException {
        return null;
      }
      return null;
    }

    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final q = uri.queryParameters;
      final id = q['seniorId'] ?? q['id'] ?? q['osca_id'];
      if (id != null && isValidId(id)) return ScannedSeniorId(normalize(id));
      return null;
    }

    if (isValidId(text)) return ScannedSeniorId(normalize(text));
    return null;
  }
}
