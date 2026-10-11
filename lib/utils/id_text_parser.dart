import '../models/personal_info.dart';
import 'senior_id_qr.dart';

/// What could be read from the text on a photo of an ID.
class IdExtraction {
  final PersonalInfo info;

  /// The fields that were found. Anything else was not on the ID, or could
  /// not be read.
  final Set<PersonalField> found;

  const IdExtraction(this.info, this.found);

  static const IdExtraction nothing = IdExtraction(PersonalInfo.empty, {});

  bool get isEmpty => found.isEmpty;

  /// Enough to be useful: a name or the ID number.
  bool get isUseful =>
      found.contains(PersonalField.seniorId) ||
      (found.contains(PersonalField.firstName) &&
          found.contains(PersonalField.lastName));
}

/// Turns the text read from a Senior Citizen ID (by the phone's text
/// recognition) into form fields. IDs from different towns look different,
/// so this only looks for common labels ("Name", "Date of Birth", "Sex",
/// "ID No.", "Address") and leaves out anything it is not sure about. The
/// result is only a suggestion for the form: the user checks it, and the
/// backend checks it against SCMS.
class IdTextParser {
  IdTextParser._();

  static final _labels = <_Label, RegExp>{
    _Label.lastName: RegExp(r'^(last\s*name|surname|apelyido)\b', caseSensitive: false),
    _Label.firstName: RegExp(r'^(first\s*name|given\s*name|pangalan)\b', caseSensitive: false),
    _Label.middleName: RegExp(r'^(middle\s*name)\b', caseSensitive: false),
    _Label.name: RegExp(r'^(full\s*name|name)\b', caseSensitive: false),
    _Label.birthDate: RegExp(
      r'^(date\s*of\s*birth|birth\s*date|birthdate|birthday|dob|petsa\s*ng\s*kapanganakan)\b',
      caseSensitive: false,
    ),
    _Label.sex: RegExp(r'^(sex|gender|kasarian)\b', caseSensitive: false),
    _Label.seniorId: RegExp(
      r'^((senior\s*citizen\s*)?(osca\s*)?(id|i\.d\.|control|card)\s*(no\.?|number|#)|osca\s*(id|no\.?)|sc\s*id)',
      caseSensitive: false,
    ),
    _Label.address: RegExp(r'^(address|tirahan|residence)\b', caseSensitive: false),
  };

  static const _monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static const _surnameParticles = {
    'de', 'del', 'dela', 'la', 'delos', 'los', 'las', 'san', 'sta', 'sta.',
    'santa', 'sto', 'sto.', 'santo', 'di', 'da', 'van', 'von',
  };

  static const _suffixes = {'jr', 'jr.', 'sr', 'sr.', 'ii', 'iii', 'iv', 'v'};

  static IdExtraction parse(String text, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final values = <_Label, String>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (final entry in _labels.entries) {
        if (values.containsKey(entry.key)) continue;
        final match = entry.value.firstMatch(line);
        if (match == null) continue;
        var value = line.substring(match.end).replaceFirst(RegExp(r'^\s*[:.\-]?\s*'), '');
        // "Date of Birth: 01/15/1945  Sex: M" - stop at the next label.
        value = _cutAtNextLabel(value);
        // Label alone on its line: the value is on the next line.
        if (value.isEmpty && i + 1 < lines.length && !_isLabel(lines[i + 1])) {
          value = lines[i + 1];
        }
        if (value.isNotEmpty) values[entry.key] = value;
        break;
      }
      // "Sex: M" written after the birthday on the same line.
      final sexInline = RegExp(r'\b(sex|gender)\s*[:.]?\s*([MF]|male|female)\b',
              caseSensitive: false)
          .firstMatch(line);
      if (sexInline != null) values.putIfAbsent(_Label.sex, () => sexInline.group(2)!);
    }

    var info = PersonalInfo.empty;
    final found = <PersonalField>{};

    // Names
    final last = values[_Label.lastName];
    final first = values[_Label.firstName];
    if (last != null && first != null) {
      info = info.copyWith(lastName: _title(last), firstName: _title(first));
      found.addAll({PersonalField.lastName, PersonalField.firstName});
      final middle = values[_Label.middleName];
      if (middle != null) {
        info = info.copyWith(middleName: _title(middle));
        found.add(PersonalField.middleName);
      }
    } else if (values[_Label.name] != null) {
      final name = splitName(values[_Label.name]!);
      if (name != null) {
        info = info.copyWith(
          firstName: name.first,
          middleName: name.middle,
          lastName: name.last,
          suffix: name.suffix,
        );
        found.addAll({PersonalField.firstName, PersonalField.lastName});
        if (name.middle.isNotEmpty) found.add(PersonalField.middleName);
        if (name.suffix.isNotEmpty) found.add(PersonalField.suffix);
      }
    }

    // Birthday
    final birth = values[_Label.birthDate];
    final birthDate = birth == null ? null : parseDate(birth, today: now);
    if (birthDate != null) {
      info = info.copyWith(birthDate: birthDate);
      found.add(PersonalField.birthDate);
    }

    // Sex
    final sex = SexInfo.tryParse(values[_Label.sex]?.split(' ').first);
    if (sex != null) {
      info = info.copyWith(sex: sex);
      found.add(PersonalField.sex);
    }

    // ID number
    final idText = values[_Label.seniorId]?.split(' ').first;
    if (idText != null && SeniorIdQr.isValidId(idText)) {
      info = info.copyWith(seniorId: SeniorIdQr.normalize(idText));
      found.add(PersonalField.seniorId);
    }

    // Address: "Brgy. Poblacion, Ubay, Bohol"
    final address = values[_Label.address];
    if (address != null) {
      final parts = address
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length >= 3) {
        info = info.copyWith(
          barangay: _stripBarangay(parts[parts.length - 3]),
          municipality: _title(parts[parts.length - 2]),
          province: _title(parts.last),
          addressLine: parts.length > 3
              ? parts.sublist(0, parts.length - 3).join(', ')
              : null,
        );
        found.addAll({
          PersonalField.barangay,
          PersonalField.municipality,
          PersonalField.province,
        });
        if (parts.length > 3) found.add(PersonalField.addressLine);
      } else if (parts.length == 2) {
        info = info.copyWith(
          barangay: _stripBarangay(parts[0]),
          municipality: _title(parts[1]),
        );
        found.addAll({PersonalField.barangay, PersonalField.municipality});
      } else if (parts.isNotEmpty) {
        info = info.copyWith(addressLine: parts.single);
        found.add(PersonalField.addressLine);
      }
    }

    // The card's header: "Province of Bohol", "Municipality of Ubay".
    for (final line in lines) {
      final province =
          RegExp(r'^province\s+of\s+(.+)$', caseSensitive: false).firstMatch(line);
      if (province != null && !found.contains(PersonalField.province)) {
        info = info.copyWith(province: _title(province.group(1)!));
        found.add(PersonalField.province);
      }
      final town = RegExp(r'^(municipality|city)\s+of\s+(.+)$', caseSensitive: false)
          .firstMatch(line);
      if (town != null && !found.contains(PersonalField.municipality)) {
        info = info.copyWith(municipality: _title(town.group(2)!));
        found.add(PersonalField.municipality);
      }
    }

    return IdExtraction(info, found);
  }

  /// "DELA CRUZ, JUAN SANTOS" or "Juan S. Dela Cruz Jr." -> parts.
  /// Returns null when it does not look like a name.
  static ({String first, String middle, String last, String suffix})? splitName(
      String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-zÑñ.,\-\s]'), '').trim();
    if (cleaned.length < 3) return null;

    var suffix = '';
    String takeSuffix(List<String> tokens) {
      if (tokens.length > 2 && _suffixes.contains(tokens.last.toLowerCase())) {
        return tokens.removeLast();
      }
      return '';
    }

    if (cleaned.contains(',')) {
      // "Last, First Middle"
      final comma = cleaned.indexOf(',');
      final last = cleaned.substring(0, comma).trim();
      final rest = cleaned
          .substring(comma + 1)
          .replaceAll(',', ' ')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (last.isEmpty || rest.isEmpty) return null;
      if (rest.length > 1 && _suffixes.contains(rest.last.toLowerCase())) {
        suffix = rest.removeLast();
      }
      final middle = rest.length >= 2 ? rest.removeLast() : '';
      return (
        first: _title(rest.join(' ')),
        middle: _title(middle),
        last: _title(last),
        suffix: _suffix(suffix),
      );
    }

    final tokens =
        cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 2) return null;
    suffix = takeSuffix(tokens);

    // Last name: the last word, plus "Dela", "De Los"... before it.
    var lastStart = tokens.length - 1;
    while (lastStart > 1 &&
        _surnameParticles.contains(tokens[lastStart - 1].toLowerCase())) {
      lastStart--;
    }
    final last = tokens.sublist(lastStart).join(' ');
    final given = tokens.sublist(0, lastStart);
    final middle = given.length >= 2 ? given.removeLast() : '';
    return (
      first: _title(given.join(' ')),
      middle: _title(middle.replaceAll('.', '')),
      last: _title(last),
      suffix: _suffix(suffix),
    );
  }

  /// Reads "01/15/1945", "1945-01-15", "January 15, 1945", "15 Jan 1945".
  /// Returns null when it is not a real date, or not a possible birthday.
  static DateTime? parseDate(String raw, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final text = raw.trim().toLowerCase();
    DateTime? date;

    final iso = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(text);
    if (iso != null) {
      date = _make(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    }
    if (date == null) {
      // Philippine IDs write month first: MM/DD/YYYY.
      final md = RegExp(r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})').firstMatch(text);
      if (md != null) {
        final a = int.parse(md[1]!), b = int.parse(md[2]!), y = int.parse(md[3]!);
        date = _make(y, a, b) ?? (a > 12 ? _make(y, b, a) : null);
      }
    }
    if (date == null) {
      final named = RegExp(r'([a-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{4})').firstMatch(text);
      final month = named == null ? null : _monthNames[named[1]!.substring(0, 3)];
      if (named != null && month != null) {
        date = _make(int.parse(named[3]!), month, int.parse(named[2]!));
      }
    }
    if (date == null) {
      final named = RegExp(r'(\d{1,2})\s+([a-z]{3,9})\.?,?\s+(\d{4})').firstMatch(text);
      final month = named == null ? null : _monthNames[named[2]!.substring(0, 3)];
      if (named != null && month != null) {
        date = _make(int.parse(named[3]!), month, int.parse(named[1]!));
      }
    }
    if (date == null || date.year < 1900 || date.isAfter(now)) return null;
    return date;
  }

  /// A real calendar date, or null (no "February 30").
  static DateTime? _make(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return (date.year == y && date.month == m && date.day == d) ? date : null;
  }

  static bool _isLabel(String line) =>
      _labels.values.any((r) => r.hasMatch(line));

  static String _cutAtNextLabel(String value) {
    final next = RegExp(
      r'\s+(sex|gender|date\s*of\s*birth|birth\s*date|address|id\s*no|date\s*issued|valid)\b',
      caseSensitive: false,
    ).firstMatch(value);
    return (next == null ? value : value.substring(0, next.start)).trim();
  }

  static String _stripBarangay(String s) => _title(
      s.replaceFirst(RegExp(r'^(brgy\.?|barangay|bgy\.?)\s*', caseSensitive: false), ''));

  static String _suffix(String s) {
    final lower = s.toLowerCase().replaceAll('.', '');
    if (lower == 'jr' || lower == 'sr') return '${lower[0].toUpperCase()}${lower[1]}.';
    return s.toUpperCase();
  }

  /// "DELA CRUZ" -> "Dela Cruz"
  static String _title(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.length == 1
          ? w.toUpperCase()
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}

enum _Label { lastName, firstName, middleName, name, birthDate, sex, seniorId, address }
