import '../../app_state/user_provider.dart';
import '../../models/onboarding_stage.dart';
import '../../services/auth_service.dart';
import '../../utils/mpin_validator.dart';

/// Shared, low-level code (OTP) step: asks Laravel to text a 4-digit code
/// for one purpose, and asks Laravel to check it. The code is generated,
/// sent, expired and limited by the backend; the app never knows it and
/// never checks it itself. Each flow has its own OtpChallenge.
class OtpChallenge {
  OtpChallenge(this._auth, this.purpose);

  final AuthService _auth;
  final AuthFlow purpose;

  /// Wrong codes allowed for one code before a new one must be asked for.
  /// The backend has its own limit; this one stops the app from sending
  /// guesses it already knows will be refused.
  static const int maxAttempts = 5;

  String _phone = '';
  OtpTicket _ticket = const OtpTicket();
  DateTime? _sentAt;
  int _failed = 0;
  String? _verificationToken;
  String? _verifiedCode;

  /// The 10-digit number the code was sent to.
  String get phone => _phone;
  OtpTicket get ticket => _ticket;
  DateTime? get sentAt => _sentAt;

  /// The backend's single-use ticket for the next step, once the code was
  /// right. Null before that.
  String? get verificationToken => _verificationToken;

  /// The code that was accepted (only to refuse it as an MPIN).
  String? get verifiedCode => _verifiedCode;

  bool get expired {
    final sent = _sentAt;
    return sent == null || DateTime.now().isAfter(sent.add(_ticket.expiresIn));
  }

  bool get locked => _failed >= maxAttempts;

  /// Sends a code to [rawPhone]. Throws [AuthException] when the number is
  /// not valid or the backend refuses (e.g. account already exists).
  Future<void> send(String rawPhone) async {
    final phone = UserProvider.normalizePhone(rawPhone);
    if (!UserProvider.isValidPhone(phone)) {
      throw const AuthException(AuthError.invalidPhone);
    }
    final ticket = await _auth.requestOtp(phone: phone, flow: purpose);
    clear();
    _phone = phone;
    _ticket = ticket;
    _sentAt = DateTime.now();
  }

  /// "Resend OTP": a new code; the old one stops working.
  Future<void> resend() async {
    if (_phone.isEmpty) throw const AuthException(AuthError.verificationExpired);
    final ticket = await _auth.requestOtp(phone: _phone, flow: purpose);
    _failed = 0;
    _verificationToken = null;
    _verifiedCode = null;
    _ticket = ticket;
    _sentAt = DateTime.now();
  }

  /// Sends [code] to the backend to check.
  Future<void> verify(String code) async {
    if (_phone.isEmpty) throw const AuthException(AuthError.verificationExpired);
    if (OtpValidator.validate(code) != null) {
      throw const AuthException(AuthError.wrongCode);
    }
    if (locked) throw const AuthException(AuthError.tooManyAttempts);
    if (expired) throw const AuthException(AuthError.codeExpired);

    try {
      _verificationToken =
          await _auth.verifyOtp(phone: _phone, code: code, flow: purpose);
      _verifiedCode = code;
    } on AuthException catch (e) {
      if (e.error == AuthError.wrongCode) {
        _failed++;
        final left = e.attemptsLeft;
        if (locked || (left != null && left <= 0)) {
          _failed = maxAttempts;
          throw const AuthException(AuthError.tooManyAttempts);
        }
      } else if (e.error == AuthError.tooManyAttempts) {
        _failed = maxAttempts;
      }
      rethrow;
    }
  }

  /// Forgets everything (keeps nothing about the code or the ticket).
  void clear() {
    _phone = '';
    _ticket = const OtpTicket();
    _sentAt = null;
    _failed = 0;
    _verificationToken = null;
    _verifiedCode = null;
  }
}
