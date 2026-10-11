/// The senior's record at the OSCA office (the source of truth). Shown on
/// Personal information; locked once the application is approved or the
/// account is linked to the record.
class OscaRecord {
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final DateTime? birthDate;
  final String sex;
  final String civilStatus;
  final String placeOfBirth;
  final String citizenship;

  /// Empty until the application is approved.
  final String oscaIdNumber;

  /// Empty until the application is approved.
  final DateTime? dateRegistered;
  final String barangay;

  const OscaRecord({
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.suffix = '',
    this.birthDate,
    this.sex = '',
    this.civilStatus = '',
    this.placeOfBirth = '',
    this.citizenship = '',
    this.oscaIdNumber = '',
    this.dateRegistered,
    this.barangay = '',
  });

  String get fullName => [firstName, middleName, lastName, suffix]
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(' ');

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'suffix': suffix,
        'birthDate': birthDate?.toIso8601String(),
        'sex': sex,
        'civilStatus': civilStatus,
        'placeOfBirth': placeOfBirth,
        'citizenship': citizenship,
        'oscaIdNumber': oscaIdNumber,
        'dateRegistered': dateRegistered?.toIso8601String(),
        'barangay': barangay,
      };

  factory OscaRecord.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k] as String? ?? '';
    return OscaRecord(
      firstName: s('firstName'),
      middleName: s('middleName'),
      lastName: s('lastName'),
      suffix: s('suffix'),
      birthDate: DateTime.tryParse(s('birthDate')),
      sex: s('sex'),
      civilStatus: s('civilStatus'),
      placeOfBirth: s('placeOfBirth'),
      citizenship: s('citizenship'),
      oscaIdNumber: s('oscaIdNumber'),
      dateRegistered: DateTime.tryParse(s('dateRegistered')),
      barangay: s('barangay'),
    );
  }
}
