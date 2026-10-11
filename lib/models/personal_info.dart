import 'package:intl/intl.dart';

/// The words the SCMS web uses are sent as-is ("male", "widowed"), so the
/// backend can map them to its own columns.
enum Sex { male, female }

extension SexInfo on Sex {
  String get label => this == Sex.male ? 'Male' : 'Female';

  /// Accepts "M", "Male", "FEMALE", "f"...
  static Sex? tryParse(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    if (v == 'm' || v == 'male' || v == 'lalaki') return Sex.male;
    if (v == 'f' || v == 'female' || v == 'babae') return Sex.female;
    return null;
  }
}

enum CivilStatus { single, married, widowed, separated, annulled }

extension CivilStatusInfo on CivilStatus {
  String get label => switch (this) {
        CivilStatus.single => 'Single',
        CivilStatus.married => 'Married',
        CivilStatus.widowed => 'Widowed',
        CivilStatus.separated => 'Separated',
        CivilStatus.annulled => 'Annulled',
      };

  static CivilStatus? tryParse(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    for (final s in CivilStatus.values) {
      if (s.name == v) return s;
    }
    if (v == 'widow' || v == 'widower') return CivilStatus.widowed;
    return null;
  }
}

/// Where the information on the form came from. Only [record] came from the
/// SCMS database; everything else is what the user (or the phone) read and
/// still has to be checked by the backend.
enum InfoSource { record, qr, idPhoto, manual }

/// The fields of the personal information form. Used to say which fields
/// are managed by OSCA, and which one a correction request is about.
enum PersonalField {
  firstName,
  middleName,
  lastName,
  suffix,
  birthDate,
  sex,
  civilStatus,
  seniorId,
  email,
  province,
  municipality,
  barangay,
  purok,
  addressLine,
}

extension PersonalFieldInfo on PersonalField {
  String get label => switch (this) {
        PersonalField.firstName => 'First name',
        PersonalField.middleName => 'Middle name',
        PersonalField.lastName => 'Last name',
        PersonalField.suffix => 'Suffix (Jr., Sr., III)',
        PersonalField.birthDate => 'Date of birth',
        PersonalField.sex => 'Sex',
        PersonalField.civilStatus => 'Civil status',
        PersonalField.seniorId => 'Senior Citizen / OSCA ID',
        PersonalField.email => 'Email',
        PersonalField.province => 'Province',
        PersonalField.municipality => 'City / Municipality',
        PersonalField.barangay => 'Barangay',
        PersonalField.purok => 'Purok / Sitio',
        PersonalField.addressLine => 'House no. / Street',
      };

  /// Official identity fields. Once the account is linked to an SCMS record,
  /// only the OSCA office can change these (through a correction request).
  static const Set<PersonalField> oscaManaged = {
    PersonalField.firstName,
    PersonalField.middleName,
    PersonalField.lastName,
    PersonalField.suffix,
    PersonalField.birthDate,
    PersonalField.sex,
    PersonalField.civilStatus,
    PersonalField.seniorId,
    PersonalField.province,
    PersonalField.municipality,
    PersonalField.barangay,
  };

  bool get isOscaManaged => oscaManaged.contains(this);

  static PersonalField? tryParse(String? name) {
    for (final f in PersonalField.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}

/// A senior citizen's personal information, as typed, read from an ID, or
/// returned by the SCMS backend. The JSON keys are the ones the /api/mobile
/// routes use.
class PersonalInfo {
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final DateTime? birthDate;
  final Sex? sex;
  final CivilStatus? civilStatus;

  /// Senior Citizen / OSCA ID number, e.g. "UBY-2026-00128". Empty when the
  /// senior does not have one yet.
  final String seniorId;

  /// 10 digits, no +63. This is the number the user signed in with.
  final String mobile;
  final String email;

  final String province;
  final String municipality;
  final String barangay;
  final String purok;
  final String addressLine;

  const PersonalInfo({
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.suffix = '',
    this.birthDate,
    this.sex,
    this.civilStatus,
    this.seniorId = '',
    this.mobile = '',
    this.email = '',
    this.province = '',
    this.municipality = '',
    this.barangay = '',
    this.purok = '',
    this.addressLine = '',
  });

  static const PersonalInfo empty = PersonalInfo();

  /// "Juan Santos Dela Cruz Jr."
  String get fullName => [firstName, middleName, lastName, suffix]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(' ');

  /// "Purok 3, Poblacion, Ubay, Bohol"
  String get fullAddress => [addressLine, purok, barangay, municipality, province]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');

  String get birthDateLabel =>
      birthDate == null ? '' : DateFormat('MMMM d, y').format(birthDate!);

  /// True when nothing at all was filled in.
  bool get isEmpty =>
      fullName.isEmpty &&
      birthDate == null &&
      sex == null &&
      seniorId.trim().isEmpty &&
      fullAddress.isEmpty;

  /// The value of [field] as text, for summaries and correction requests.
  String valueOf(PersonalField field) => switch (field) {
        PersonalField.firstName => firstName,
        PersonalField.middleName => middleName,
        PersonalField.lastName => lastName,
        PersonalField.suffix => suffix,
        PersonalField.birthDate => birthDateLabel,
        PersonalField.sex => sex?.label ?? '',
        PersonalField.civilStatus => civilStatus?.label ?? '',
        PersonalField.seniorId => seniorId,
        PersonalField.email => email,
        PersonalField.province => province,
        PersonalField.municipality => municipality,
        PersonalField.barangay => barangay,
        PersonalField.purok => purok,
        PersonalField.addressLine => addressLine,
      };

  /// Fills the empty fields of this with the ones in [other]. Used to put
  /// what was read from an ID under what the user already typed.
  PersonalInfo fillBlanksFrom(PersonalInfo other) {
    String pick(String mine, String theirs) =>
        mine.trim().isNotEmpty ? mine : theirs;
    return PersonalInfo(
      firstName: pick(firstName, other.firstName),
      middleName: pick(middleName, other.middleName),
      lastName: pick(lastName, other.lastName),
      suffix: pick(suffix, other.suffix),
      birthDate: birthDate ?? other.birthDate,
      sex: sex ?? other.sex,
      civilStatus: civilStatus ?? other.civilStatus,
      seniorId: pick(seniorId, other.seniorId),
      mobile: pick(mobile, other.mobile),
      email: pick(email, other.email),
      province: pick(province, other.province),
      municipality: pick(municipality, other.municipality),
      barangay: pick(barangay, other.barangay),
      purok: pick(purok, other.purok),
      addressLine: pick(addressLine, other.addressLine),
    );
  }

  /// Replaces the [fields] of this with the ones in [record] (the SCMS
  /// database wins for those fields).
  PersonalInfo overrideWith(PersonalInfo record, Set<PersonalField> fields) {
    String take(PersonalField f, String mine, String theirs) =>
        fields.contains(f) ? theirs : mine;
    return PersonalInfo(
      firstName: take(PersonalField.firstName, firstName, record.firstName),
      middleName: take(PersonalField.middleName, middleName, record.middleName),
      lastName: take(PersonalField.lastName, lastName, record.lastName),
      suffix: take(PersonalField.suffix, suffix, record.suffix),
      birthDate:
          fields.contains(PersonalField.birthDate) ? record.birthDate : birthDate,
      sex: fields.contains(PersonalField.sex) ? record.sex : sex,
      civilStatus: fields.contains(PersonalField.civilStatus)
          ? record.civilStatus
          : civilStatus,
      seniorId: take(PersonalField.seniorId, seniorId, record.seniorId),
      mobile: mobile,
      email: take(PersonalField.email, email, record.email),
      province: take(PersonalField.province, province, record.province),
      municipality:
          take(PersonalField.municipality, municipality, record.municipality),
      barangay: take(PersonalField.barangay, barangay, record.barangay),
      purok: take(PersonalField.purok, purok, record.purok),
      addressLine:
          take(PersonalField.addressLine, addressLine, record.addressLine),
    );
  }

  PersonalInfo copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    DateTime? birthDate,
    Sex? sex,
    CivilStatus? civilStatus,
    String? seniorId,
    String? mobile,
    String? email,
    String? province,
    String? municipality,
    String? barangay,
    String? purok,
    String? addressLine,
  }) {
    return PersonalInfo(
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      civilStatus: civilStatus ?? this.civilStatus,
      seniorId: seniorId ?? this.seniorId,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      province: province ?? this.province,
      municipality: municipality ?? this.municipality,
      barangay: barangay ?? this.barangay,
      purok: purok ?? this.purok,
      addressLine: addressLine ?? this.addressLine,
    );
  }

  Map<String, dynamic> toJson() => {
        'firstName': firstName.trim(),
        'middleName': middleName.trim(),
        'lastName': lastName.trim(),
        'suffix': suffix.trim(),
        'birthDate': birthDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(birthDate!),
        'sex': sex?.name,
        'civilStatus': civilStatus?.name,
        'seniorId': seniorId.trim(),
        'mobile': mobile,
        'email': email.trim(),
        'province': province.trim(),
        'municipality': municipality.trim(),
        'barangay': barangay.trim(),
        'purok': purok.trim(),
        'addressLine': addressLine.trim(),
      };

  /// Form fields for multipart requests (no nulls).
  Map<String, String> toFields() => {
        for (final e in toJson().entries)
          if (e.value != null) e.key: e.value.toString(),
      };

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] as Object?)?.toString() ?? '';
    return PersonalInfo(
      firstName: s('firstName'),
      middleName: s('middleName'),
      lastName: s('lastName'),
      suffix: s('suffix'),
      birthDate: DateTime.tryParse(s('birthDate')),
      sex: SexInfo.tryParse(s('sex')),
      civilStatus: CivilStatusInfo.tryParse(s('civilStatus')),
      seniorId: s('seniorId'),
      mobile: s('mobile'),
      email: s('email'),
      province: s('province'),
      municipality: s('municipality'),
      barangay: s('barangay'),
      purok: s('purok'),
      addressLine: s('addressLine'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PersonalInfo &&
      _eq(toJson(), other.toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);

  static bool _eq(Map<String, dynamic> a, Map<String, dynamic> b) {
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
