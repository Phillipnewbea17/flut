import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_mode.dart';

/// DEMO MODE ONLY (see demo_mode.dart): a stand-in for the SCMS Laravel
/// backend that runs on the phone. It answers the same /api/mobile routes
/// with the same JSON and error codes as the real backend, so the app runs
/// its normal code. Accounts and requests are saved on this phone only and
/// never reach the web admin.
///
/// Differences from the real backend, to make trying the app easy:
/// - the sign-in code is always [kDemoOtp] (no text message);
/// - a new account is linked at once to a sample senior citizen record
///   with the name typed in Create Account, so My ID, pension and the
///   request services can be tried.
class DemoBackend extends http.BaseClient {
  DemoBackend._(this._prefs, this._state);

  /// The address the app is given in demo mode (never contacted).
  static const String baseUrl = 'https://demo.scms.local';

  static const _key = 'demo_backend_v1';
  static const _latency = Duration(milliseconds: 350);
  static const _maxCodeTries = 5;
  static const _maxMpinTries = 5;

  final SharedPreferences _prefs;
  final Map<String, dynamic> _state;

  static Future<DemoBackend> open() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> state;
    try {
      state = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_key) ?? '{}') as Map);
    } catch (_) {
      state = {};
    }
    for (final k in ['accounts', 'codes', 'tickets', 'sessions']) {
      state[k] = Map<String, dynamic>.from((state[k] as Map?) ?? {});
    }
    state['counter'] ??= 0;
    return DemoBackend._(prefs, state);
  }

  Map<String, dynamic> get _accounts => _state['accounts'] as Map<String, dynamic>;
  Map<String, dynamic> get _codes => _state['codes'] as Map<String, dynamic>;
  Map<String, dynamic> get _tickets => _state['tickets'] as Map<String, dynamic>;
  Map<String, dynamic> get _sessions => _state['sessions'] as Map<String, dynamic>;

  Future<void> _save() => _prefs.setString(_key, jsonEncode(_state));

  String _next(String prefix) {
    final n = (_state['counter'] as int) + 1;
    _state['counter'] = n;
    return '$prefix-${DateTime.now().year}-${n.toString().padLeft(4, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------------

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(_latency);
    final path = request.url.path.replaceFirst('/api/mobile', '');
    final body = <String, dynamic>{};
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) body.addAll(Map<String, dynamic>.from(decoded));
    } else if (request is http.MultipartRequest) {
      body.addAll(request.fields);
    }
    final auth = request.headers['Authorization'] ?? '';
    final phone = auth.startsWith('Bearer ')
        ? _sessions[auth.substring(7)] as String?
        : null;

    _Reply reply;
    try {
      reply = await _route(request.method, path, body, phone, auth);
    } on _Reply catch (error) {
      reply = error;
    }
    await _save();
    final bytes = utf8.encode(jsonEncode(reply.body));
    return http.StreamedResponse(
      Stream.value(bytes),
      reply.status,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  static _Reply _fail(int status, String code, String message,
          [Map<String, dynamic> extra = const {}]) =>
      _Reply(status, {'message': message, 'code': code, ...extra});

  Future<_Reply> _route(String method, String path, Map<String, dynamic> body,
      String? phone, String auth) async {
    final key = '$method $path';

    // Public routes.
    switch (key) {
      case 'POST /auth/code':
        return _sendCode(body);
      case 'POST /auth/verify':
        return _verifyCode(body);
      case 'POST /auth/register':
        return _register(body);
      case 'POST /auth/login':
        return _login(body);
      case 'POST /auth/mpin/reset':
        return _resetMpin(body);
      case 'GET /announcements':
        return _Reply(200, _announcements());
    }

    // Signed-in routes.
    if (phone == null || _accounts[phone] == null) {
      throw const _Reply(401, {'message': 'Unauthenticated.'});
    }
    final account = Map<String, dynamic>.from(_accounts[phone] as Map);
    _accounts[phone] = account;

    switch (key) {
      case 'POST /auth/sign-out':
        _sessions.remove(auth.substring(7));
        return const _Reply(200, {'message': 'Signed out.'});
      case 'POST /auth/mpin/change':
        _checkMpin(account, '${body['currentMpin']}');
        _rejectWeak('${body['mpin']}');
        account['mpin'] = '${body['mpin']}';
        return const _Reply(200, {'ok': true});
      case 'GET /profile':
        return _Reply(200, _profile(phone, account));
      case 'POST /profile':
        return _updateProfile(phone, account, body);
      case 'GET /notifications':
        return _Reply(200, _notifications(account));
      case 'GET /application':
        return _Reply(200, _application(account));
      case 'POST /documents':
        return _Reply(201, {'ok': true, 'id': _next('DOC')});
      case 'POST /application/submit':
        return _submitApplication(account);
      case 'GET /wallet':
        return _Reply(200, {'seniorId': _seniorId(account)});
      case 'GET /my-senior-id':
        // Like the real route: no link means no ID yet, not an error.
        final issued = account['linked'] == true ? _seniorId(account) : null;
        return _Reply(200, {'has_id': issued != null, 'seniorId': issued});
      case 'GET /pension':
        return _Reply(200, _pension(account));
      case 'POST /identity/lookup':
        return _Reply(200, {
          'status': 'found',
          'record': {'seniorId': '${body['seniorId'] ?? ''}'},
          'lockedFields': ['seniorId'],
        });
      case 'POST /identity/verify':
        account['linked'] = true;
        return _Reply(200, {'status': 'verified', 'profile': _profile(phone, account)});
      case 'GET /profile/corrections':
        return const _Reply(200, []);
      case 'POST /profile/corrections':
        return _Reply(201, {'ok': true, 'reference': _next('COR-DEMO')});
    }

    // Requests: /medical-requests, /burial-requests, /help-requests,
    // /senior-id/replacement-requests (and their /{ref}/attachments).
    for (final kind in _requestKinds.keys) {
      if (path == kind) {
        if (method == 'GET') return _Reply(200, _requests(account, kind));
        if (method == 'POST') return _newRequest(account, kind, body);
      }
      if (method == 'POST' &&
          path.startsWith('$kind/') &&
          path.endsWith('/attachments')) {
        return _Reply(201, {'ok': true, 'id': _next('ATT')});
      }
    }

    // Like Laravel: a route that does not exist answers 404 without a code.
    return const _Reply(404, {'message': 'Not Found'});
  }

  // ---------------------------------------------------------------------------
  // Sign-in (same rules and error codes as Mobile\AuthController)
  // ---------------------------------------------------------------------------

  static const _purposes = {'register', 'login', 'reset_mpin'};

  String _phoneOf(Map<String, dynamic> body) {
    final phone = '${body['phone'] ?? ''}';
    if (!RegExp(r'^9\d{9}$').hasMatch(phone)) {
      throw _fail(422, 'invalid_phone', 'Please enter a valid mobile number.');
    }
    return phone;
  }

  _Reply _sendCode(Map<String, dynamic> body) {
    final phone = _phoneOf(body);
    final purpose = '${body['purpose']}';
    if (!_purposes.contains(purpose)) {
      throw _fail(422, 'invalid_purpose', 'Please update the app.');
    }
    final exists = _accounts.containsKey(phone);
    if (purpose == 'register' && exists) {
      throw _fail(409, 'already_registered',
          'This mobile number is already registered. Please log in instead.');
    }
    if (purpose != 'register' && !exists) {
      throw _fail(404, 'account_not_found',
          'Account not found. Please create an account first.');
    }
    _codes[phone] = {
      'purpose': purpose,
      'sentAt': DateTime.now().toIso8601String(),
      'tries': 0,
    };
    // Demo: a short wait so "Resend OTP" can be tried quickly.
    return const _Reply(200, {
      'message': 'We sent a code to your phone.',
      'expiresIn': 300,
      'resendIn': 20,
    });
  }

  _Reply _verifyCode(Map<String, dynamic> body) {
    final phone = _phoneOf(body);
    final sent = _codes[phone] as Map?;
    if (sent == null ||
        sent['purpose'] != '${body['purpose']}' ||
        DateTime.now().difference(DateTime.parse('${sent['sentAt']}')) >
            const Duration(minutes: 5)) {
      throw _fail(422, 'expired', 'This code has expired. Please request a new code.');
    }
    var tries = sent['tries'] as int;
    if (tries >= _maxCodeTries) {
      throw _fail(429, 'too_many_attempts', 'Too many attempts.');
    }
    if ('${body['code']}' != kDemoOtp) {
      tries++;
      _codes[phone] = {...sent, 'tries': tries};
      final left = _maxCodeTries - tries;
      if (left <= 0) throw _fail(429, 'too_many_attempts', 'Too many attempts.');
      throw _fail(422, 'wrong_code', 'That code is incorrect.',
          {'attemptsLeft': left});
    }
    _codes.remove(phone);
    final ticket = 'demo-ticket-${DateTime.now().microsecondsSinceEpoch}';
    _tickets[ticket] = {'phone': phone, 'purpose': sent['purpose']};
    return _Reply(200, {'verificationToken': ticket, 'expiresIn': 600});
  }

  void _redeem(Map<String, dynamic> body, String phone, String purpose) {
    final ticket = _tickets['${body['verificationToken']}'] as Map?;
    if (ticket == null ||
        ticket['phone'] != phone ||
        ticket['purpose'] != purpose) {
      throw _fail(422, 'verification_expired',
          'Your verification has expired. Please start again.');
    }
  }

  void _rejectWeak(String mpin) {
    if (!RegExp(r'^\d{4}$').hasMatch(mpin)) {
      throw _fail(422, 'invalid_mpin', 'Please enter exactly 4 numbers.');
    }
    final d = mpin.codeUnits.map((c) => c - 48).toList();
    var up = true, down = true;
    for (var i = 1; i < d.length; i++) {
      up = up && d[i] == d[i - 1] + 1;
      down = down && d[i] == d[i - 1] - 1;
    }
    if (d.toSet().length == 1 || up || down || mpin == kDemoOtp) {
      throw _fail(422, 'weak_mpin', 'This MPIN is too easy to guess.');
    }
  }

  String _session(String phone) {
    final token = 'demo-session-${DateTime.now().microsecondsSinceEpoch}';
    _sessions[token] = phone;
    return token;
  }

  _Reply _register(Map<String, dynamic> body) {
    final phone = _phoneOf(body);
    String text(String k) => '${body[k] ?? ''}'.trim();
    final noMiddle = body['noMiddleName'] == true;
    final nameOk = RegExp(r"^[A-Za-zÑñ .'\-]+$");
    if (!nameOk.hasMatch(text('firstName')) ||
        !nameOk.hasMatch(text('lastName')) ||
        (noMiddle ? text('middleName').isNotEmpty : !nameOk.hasMatch(text('middleName')))) {
      throw _fail(422, 'invalid_name', 'Please check your name.');
    }
    _redeem(body, phone, 'register');
    _rejectWeak('${body['mpin']}');
    if (_accounts.containsKey(phone)) {
      throw _fail(409, 'already_registered',
          'This mobile number is already registered. Please log in instead.');
    }
    _tickets.remove('${body['verificationToken']}');
    _accounts[phone] = {
      'mpin': '${body['mpin']}',
      'mpinTries': 0,
      'firstName': text('firstName'),
      'middleName': noMiddle ? '' : text('middleName'),
      'lastName': text('lastName'),
      'suffix': text('suffix'),
      'noMiddleName': noMiddle,
      // Demo: linked at once to a sample record (see the class comment).
      'linked': true,
      'seniorId': _next('DEMO-SC'),
      'birthDate': '1958-03-14',
      'createdAt': DateTime.now().toIso8601String(),
      'requests': <String, dynamic>{},
    };
    return _Reply(201, {
      'token': _session(phone),
      'deviceKey': _trustDevice(_accounts[phone] as Map<String, dynamic>),
    });
  }

  /// Like Laravel: a verified code trusts the phone (MPIN-only login).
  String _trustDevice(Map<String, dynamic> account) {
    final key = 'demo-device-${DateTime.now().microsecondsSinceEpoch}';
    final devices = [...(account['devices'] as List? ?? const []), key];
    account['devices'] = devices.skip(devices.length > 3 ? devices.length - 3 : 0).toList();
    return key;
  }

  void _checkMpin(Map<String, dynamic> account, String mpin) {
    final lockedUntil = DateTime.tryParse('${account['lockedUntil'] ?? ''}');
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      throw _fail(423, 'mpin_locked', 'Too many wrong MPIN tries.');
    }
    if (account['mpin'] == mpin) {
      account['mpinTries'] = 0;
      return;
    }
    final tries = (account['mpinTries'] as int? ?? 0) + 1;
    if (tries >= _maxMpinTries) {
      account['mpinTries'] = 0;
      account['lockedUntil'] =
          DateTime.now().add(const Duration(minutes: 1)).toIso8601String();
      throw _fail(423, 'mpin_locked', 'Too many wrong MPIN tries.');
    }
    account['mpinTries'] = tries;
    throw _fail(422, 'wrong_mpin', 'Your MPIN is incorrect.',
        {'attemptsLeft': _maxMpinTries - tries});
  }

  _Reply _login(Map<String, dynamic> body) {
    final phone = _phoneOf(body);
    final deviceKey = '${body['deviceKey'] ?? ''}';
    if (deviceKey.isNotEmpty) {
      final account = _accounts[phone] as Map<String, dynamic>?;
      if (account == null) {
        throw _fail(404, 'account_not_found', 'Account not found.');
      }
      if (!(account['devices'] as List? ?? const []).contains(deviceKey)) {
        throw _fail(422, 'device_not_trusted',
            'Please confirm this phone with a code first.');
      }
      _checkMpin(account, '${body['mpin']}');
      return _Reply(200, {'token': _session(phone)});
    }
    _redeem(body, phone, 'login');
    final account = _accounts[phone] as Map<String, dynamic>?;
    if (account == null) {
      throw _fail(404, 'account_not_found', 'Account not found.');
    }
    _checkMpin(account, '${body['mpin']}');
    _tickets.remove('${body['verificationToken']}');
    return _Reply(200, {
      'token': _session(phone),
      'deviceKey': _trustDevice(account),
    });
  }

  _Reply _resetMpin(Map<String, dynamic> body) {
    final phone = _phoneOf(body);
    _redeem(body, phone, 'reset_mpin');
    final account = _accounts[phone] as Map<String, dynamic>?;
    if (account == null) {
      throw _fail(404, 'account_not_found', 'Account not found.');
    }
    _rejectWeak('${body['mpin']}');
    account
      ..['mpin'] = '${body['mpin']}'
      ..['mpinTries'] = 0
      ..remove('lockedUntil')
      ..remove('devices');
    _tickets.remove('${body['verificationToken']}');
    _sessions.removeWhere((_, p) => p == phone);
    return _Reply(200, {'ok': true, 'deviceKey': _trustDevice(account)});
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  static String _fullName(Map<String, dynamic> a) => [
        a['firstName'],
        a['middleName'],
        a['lastName'],
        a['suffix'],
      ].map((s) => '${s ?? ''}'.trim()).where((s) => s.isNotEmpty).join(' ');

  Map<String, dynamic> _profile(String phone, Map<String, dynamic> a) => {
        'phone': phone,
        'mobile': phone,
        'fullName': _fullName(a),
        'firstName': a['firstName'] ?? '',
        'middleName': a['middleName'] ?? '',
        'lastName': a['lastName'] ?? '',
        'suffix': a['suffix'] ?? '',
        'noMiddleName': a['noMiddleName'] ?? false,
        'role': 'senior',
        'birthDate': a['birthDate'],
        'seniorId': a['seniorId'] ?? '',
        'purok': 'Purok 3',
        'barangay': a['barangay'] ?? 'Poblacion',
        'municipality': a['municipality'] ?? 'Ubay',
        'province': a['province'] ?? 'Bohol',
        'identityStatus': a['linked'] == true ? 'verified' : 'unverified',
        'registrationStatus': a['linked'] == true ? 'Active' : '',
        'photoUrl': '',
      };

  _Reply _updateProfile(
      String phone, Map<String, dynamic> a, Map<String, dynamic> body) {
    for (final k in [
      'firstName',
      'middleName',
      'lastName',
      'suffix',
      'noMiddleName',
      'barangay',
      'municipality',
      'province',
    ]) {
      if (body.containsKey(k) && body[k] != null) a[k] = body[k];
    }
    final birth = '${body['birthDate'] ?? ''}';
    if (birth.length >= 10) a['birthDate'] = birth.substring(0, 10);
    return _Reply(200, {'ok': true, 'profile': _profile(phone, a)});
  }

  // ---------------------------------------------------------------------------
  // Sample data
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _announcements() {
    final today = DateTime.now();
    String day(int back) =>
        '${today.subtract(Duration(days: back)).toIso8601String().substring(0, 10)}T08:00:00';
    return [
      {
        'id': 'demo-1',
        'title': 'Pension payout this Friday',
        'body': 'Bring your Senior Citizen ID to the barangay hall, 8 AM to 3 PM.',
        'date': day(1),
      },
      {
        'id': 'demo-2',
        'title': 'Free blood pressure check',
        'body': 'Every Wednesday at the Rural Health Unit.',
        'date': day(6),
      },
    ];
  }

  Map<String, dynamic>? _seniorId(Map<String, dynamic> a) {
    if (a['linked'] != true) {
      throw _fail(403, 'not_linked',
          'Your account is not linked to your senior citizen record yet.');
    }
    return {
      'idNumber': a['seniorId'],
      'fullName': _fullName(a),
      'birthDate': a['birthDate'],
      'address': 'Purok 3, Poblacion, Ubay, Bohol',
      'issuedBy': 'OSCA (demo)',
      'issuedAt': '${a['createdAt']}'.substring(0, 10),
      'status': 'Active',
      'photoUrl': '',
    };
  }

  List<Map<String, dynamic>> _pension(Map<String, dynamic> a) {
    _seniorId(a); // linked only, like the real backend
    final year = DateTime.now().year;
    return [
      {
        'period': 'July–September $year',
        'status': 'Released',
        'releaseDate': '$year-09-30',
        'reference': 'PEN-DEMO-0002',
      },
      {
        'period': 'April–June $year',
        'status': 'Released',
        'releaseDate': '$year-06-28',
        'reference': 'PEN-DEMO-0001',
      },
    ];
  }

  Map<String, dynamic> _application(Map<String, dynamic> a) {
    final app = a['application'] as Map?;
    if (app == null) {
      return {
        'applicationNo': '',
        'stage': 'notStarted',
        'message': '',
        'updatedAt': null,
        'history': <dynamic>[],
      };
    }
    return Map<String, dynamic>.from(app);
  }

  _Reply _submitApplication(Map<String, dynamic> a) {
    final now = DateTime.now().toIso8601String();
    final reference = _next('APP-DEMO');
    a['application'] = {
      'applicationNo': reference,
      'stage': 'submitted',
      'message': 'We received your papers. The OSCA office will check them soon.',
      'updatedAt': now,
      'history': [
        {'stage': 'submitted', 'date': now, 'note': 'Application sent from the app.'},
      ],
    };
    return _Reply(201, {'ok': true, 'reference': reference});
  }

  List<Map<String, dynamic>> _notifications(Map<String, dynamic> a) {
    final items = <Map<String, dynamic>>[
      {
        'id': 'demo-welcome',
        'title': 'Welcome to SCMS',
        'body': 'Mabuhay, ${a['firstName']}! This is the demo version of the app.',
        'date': a['createdAt'],
      },
    ];
    final requests = Map<String, dynamic>.from((a['requests'] as Map?) ?? {});
    for (final list in requests.values) {
      for (final r in (list as List).cast<Map>()) {
        items.add({
          'id': 'demo-${r['reference']}',
          'title': 'Request received',
          'body': '${r['title']} (${r['reference']}) was received by the OSCA office.',
          'date': r['submittedAt'],
        });
      }
    }
    items.sort((x, y) => '${y['date']}'.compareTo('${x['date']}'));
    return items;
  }

  // ---------------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------------

  static const Map<String, (String, String)> _requestKinds = {
    '/medical-requests': ('MED-DEMO', 'Medical assistance'),
    '/burial-requests': ('BUR-DEMO', 'Burial assistance'),
    '/help-requests': ('HLP-DEMO', 'Help & complaints'),
    '/senior-id/replacement-requests': ('IDR-DEMO', 'ID replacement'),
  };

  List<dynamic> _requests(Map<String, dynamic> a, String kind) {
    _seniorId(a); // linked only, like the real backend
    final requests = Map<String, dynamic>.from((a['requests'] as Map?) ?? {});
    return List<dynamic>.from((requests[kind] as List?) ?? const []);
  }

  _Reply _newRequest(
      Map<String, dynamic> a, String kind, Map<String, dynamic> body) {
    final list = _requests(a, kind);
    final clientId = '${body['clientId'] ?? ''}';
    for (final r in list.cast<Map>()) {
      if (r['clientId'] == clientId) {
        return _Reply(200, {'ok': true, 'reference': r['reference'], 'status': r['status']});
      }
    }
    final (prefix, label) = _requestKinds[kind]!;
    final now = DateTime.now().toIso8601String();
    final reference = _next(prefix);
    final title = '${body['assistanceType'] ?? body['subject'] ?? body['reason'] ?? label}';
    list.insert(0, {
      'clientId': clientId,
      'reference': reference,
      'status': 'Pending',
      'title': title.isEmpty ? label : title,
      'submittedAt': now,
      'updatedAt': now,
      'latestResponse': '',
      'details': <dynamic>[],
      'history': [
        {'date': now, 'note': 'The OSCA office received your request.'},
      ],
    });
    final requests = Map<String, dynamic>.from((a['requests'] as Map?) ?? {});
    requests[kind] = list;
    a['requests'] = requests;
    return _Reply(201, {'ok': true, 'reference': reference, 'status': 'Pending'});
  }
}

/// One answer (also thrown for errors).
class _Reply {
  const _Reply(this.status, this.body);
  final int status;
  final Object? body;
}
