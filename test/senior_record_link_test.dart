import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_senior_app/models/identity_verification.dart';
import 'package:my_senior_app/models/personal_info.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/identity_service.dart';

/// The last step of Create Account: the backend matches the account with
/// the senior citizen record (POST /api/mobile/identity/verify).
Future<VerificationResult> _verify(int status, String body) {
  final api = ApiClient(
    baseUrl: 'http://backend:8000',
    client: MockClient((_) async => http.Response(body, status)),
  )..token = '1|secret';
  return ApiIdentityService(api).verify(
    info: PersonalInfo(
      firstName: 'Rosela',
      lastName: 'Mabuhay',
      birthDate: DateTime(1958, 3, 14),
      seniorId: 'UBY-2026-00128',
      mobile: '9171234567',
    ),
    method: IdentityMethod.manual,
    selfie: Uint8List.fromList([1, 2, 3]),
  );
}

void main() {
  test('match found: linked, may continue to Home', () async {
    final result = await _verify(200, '''
      {"status":"verified","profile":{"firstName":"Rosela",
       "lastName":"Mabuhay","identityStatus":"verified"}}''');
    expect(result.status, VerificationStatus.verified);
    expect(result.status.letsUserContinue, isTrue);
    expect(result.profile!.isVerified, isTrue);
  });

  test('no match: never a fake record, may not continue', () async {
    final result =
        await _verify(404, '{"message":"No record","code":"not_found"}');
    expect(result.status, VerificationStatus.notFound);
    expect(result.status.letsUserContinue, isFalse);
    expect(result.profile, isNull);
  });

  test('information mismatch: may not continue', () async {
    final result =
        await _verify(422, '{"message":"Mismatch","code":"info_mismatch"}');
    expect(result.status, VerificationStatus.infoMismatch);
    expect(result.status.letsUserContinue, isFalse);
  });

  test('record already linked to another account: may not continue',
      () async {
    final result =
        await _verify(409, '{"message":"Taken","code":"already_linked"}');
    expect(result.status, VerificationStatus.alreadyLinked);
    expect(result.status.letsUserContinue, isFalse);
  });
}
