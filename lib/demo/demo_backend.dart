import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


/// DEMO MODE ONLY (see demo_mode.dart): a stand-in for the SCMS Laravel
/// backend that runs on the phone. It answers the same /api/mobile routes
/// with the same JSON and error codes as the real backend, so the app runs
/// its normal code. Accounts and requests are saved on this phone only and
/// never reach the web admin.
///
/// Differences from the real backend, to make trying the app easy:
/// - the sign-in code is always [kDemoOtp] (no email is sent);
/// - a new account is linked at once to a sample senior citizen record
///   with the name typed in Create Account, so My ID, pension and the
///   request services can be tried.
class DemoBackend extends http.BaseClient {
  DemoBackend._(this._prefs, this._state);

  /// The address the app is given in demo mode (never contacted).
  static const String baseUrl = 'https://demo.scms.local';

  static const _key = 'demo_backend_v1';
  static const _latency = Duration(milliseconds: 350);
  static const _maxPasswordTries = 5;
  static const _minPassword = 8;

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
    for (final k in ['accounts', 'sessions']) {
      state[k] = Map<String, dynamic>.from((state[k] as Map?) ?? {});
    }
    state['counter'] ??= 0;
    return DemoBackend._(prefs, state);
  }

  Map<String, dynamic> get _accounts => _state['accounts'] as Map<String, dynamic>;
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
    final email = auth.startsWith('Bearer ')
        ? _sessions[auth.substring(7)] as String?
        : null;

    _Reply reply;
    try {
      reply = await _route(request.method, path, body, email, auth);
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
      String? email, String auth) async {
    final key = '$method $path';

    // Public routes.
    switch (key) {
      case 'POST /auth/register':
        return _register(body);
      case 'POST /auth/login':
        return _login(body);
      case 'POST /auth/verification/resend':
        return _resendVerification(body);
      case 'POST /auth/password/forgot':
        return _forgotPassword(body);
      case 'GET /announcements':
        return _Reply(200, _announcements());
    }

    // Signed-in routes.
    if (email == null || _accounts[email] == null) {
      throw const _Reply(401, {'message': 'Unauthenticated.'});
    }
    final account = Map<String, dynamic>.from(_accounts[email] as Map);
    _accounts[email] = account;

    switch (key) {
      case 'POST /auth/sign-out':
        _sessions.remove(auth.substring(7));
        return const _Reply(200, {'message': 'Signed out.'});
      case 'POST /auth/password/change':
        _checkPassword(account, '${body['currentPassword']}');
        account['password'] = _passwordOf(body, 'password', email);
        return const _Reply(200, {'ok': true});
      case 'GET /profile':
        return _Reply(200, _profile(email, account));
      case 'POST /profile':
        return _updateProfile(email, account, body);
      case 'GET /notifications':
        return _Reply(200, _notifications(account));
      case 'POST /notifications/read':
        return _markNotifications(account, body, 'read', true);
      case 'POST /notifications/dismiss':
        return _markNotifications(account, body, 'dismissed', true);
      case 'POST /notifications/restore':
        return _markNotifications(account, body, 'dismissed', false);
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
        return _Reply(200, {'status': 'verified', 'profile': _profile(email, account)});
      case 'GET /profile/corrections':
        return const _Reply(200, []);
      case 'POST /profile/corrections':
        return _Reply(201, {'ok': true, 'reference': _next('COR-DEMO')});
    }

    // Requests: /medical-requests, /burial-requests, /help-requests, /senior-id/replacement-requests (and their
    // /{ref}/attachments). They stay Pending: no office decides in demo
    // mode, so no certificate is ever issued here.
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

  String _emailOf(Map<String, dynamic> body) {
    final email = '${body['email'] ?? ''}'.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$').hasMatch(email)) {
      throw _fail(422, 'invalid_email', 'Please enter a valid email address.');
    }
    return email;
  }

  /// Length only, like the backend. Also refuses the obvious ones.
  String _passwordOf(Map<String, dynamic> body, String key, String email) {
    final password = '${body[key] ?? ''}';
    if (password.length < _minPassword || password.length > 72) {
      throw _fail(422, 'invalid_password',
          'Please use a password of at least $_minPassword characters.');
    }
    const common = {
      'password', 'password1', 'password123', '12345678', '123456789',
      '1234567890', 'qwertyui', 'qwerty123', '11111111', '00000000',
      'abc12345', 'iloveyou', 'senior123',
    };
    final lower = password.toLowerCase();
    if (lower == email || common.contains(lower)) {
      throw _fail(422, 'weak_password', 'This password is too easy to guess.');
    }
    return password;
  }

  String _session(String email) {
    final token = 'demo-session-${DateTime.now().microsecondsSinceEpoch}';
    _sessions[token] = email;
    return token;
  }

  _Reply _register(Map<String, dynamic> body) {
    final email = _emailOf(body);
    String text(String k) => '${body[k] ?? ''}'.trim();
    final noMiddle = body['noMiddleName'] == true;
    final nameOk = RegExp(r"^[A-Za-zÑñ .'\-]+$");
    if (!nameOk.hasMatch(text('firstName')) ||
        !nameOk.hasMatch(text('lastName')) ||
        (noMiddle ? text('middleName').isNotEmpty : !nameOk.hasMatch(text('middleName')))) {
      throw _fail(422, 'invalid_name', 'Please check your name.');
    }
    final password = _passwordOf(body, 'password', email);
    if (_accounts.containsKey(email)) {
      throw _fail(409, 'already_registered',
          'This email address is already registered. Please log in instead.');
    }

    // Typed on purpose: an untyped literal becomes Map<String, Object>, and
    // _checkPassword writes null into it.
    _accounts[email] = <String, dynamic>{
      'password': password,
      'failedLogins': 0,
      // DEMO: nothing can send an email or open a web page here, so the
      // address counts as confirmed at once. The Check Your Inbox screen
      // says so instead of waiting for a link that can never arrive.
      'emailVerified': true,
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
      'ok': true,
      'email': email,
      'verifyHours': 48,
      'demoVerified': true,
      'message': 'DEMO: no email is sent, so this address is already confirmed.',
    });
  }

  /// Wrong passwords count up; too many lock the account for a while.
  void _checkPassword(Map<String, dynamic> account, String password) {
    final lockedUntil = DateTime.tryParse('${account['lockedUntil'] ?? ''}');
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      throw _fail(423, 'account_locked', 'Too many wrong passwords.', {
        'retryAfter': lockedUntil.difference(DateTime.now()).inSeconds,
      });
    }

    if (password.isNotEmpty && password == account['password']) {
      account['failedLogins'] = 0;
      account['lockedUntil'] = null;
      return;
    }

    final tries = (account['failedLogins'] as int? ?? 0) + 1;
    if (tries >= _maxPasswordTries) {
      account['failedLogins'] = 0;
      account['lockedUntil'] =
          DateTime.now().add(const Duration(minutes: 15)).toIso8601String();
      throw _fail(423, 'account_locked', 'Too many wrong passwords.',
          {'retryAfter': 15 * 60});
    }
    account['failedLogins'] = tries;

    // The same answer as an address with no account, so neither can be
    // told from the other.
    throw _fail(422, 'invalid_credentials', 'Incorrect email or password.');
  }

  _Reply _login(Map<String, dynamic> body) {
    final email = _emailOf(body);
    final account = _accounts[email] as Map<String, dynamic>?;
    if (account == null) {
      throw _fail(422, 'invalid_credentials', 'Incorrect email or password.');
    }

    _checkPassword(account, '${body['password'] ?? ''}');
    _accounts[email] = account;

    if (account['emailVerified'] != true) {
      throw _fail(403, 'email_not_verified',
          'Please confirm your email address first.', {'email': email});
    }

    return _Reply(200, {
      'token': _session(email),
      'account': _profile(email, account),
    });
  }

  _Reply _resendVerification(Map<String, dynamic> body) {
    final email = _emailOf(body);
    final account = _accounts[email] as Map<String, dynamic>?;
    if (account == null) {
      throw _fail(422, 'invalid_credentials', 'Incorrect email or password.');
    }

    _checkPassword(account, '${body['password'] ?? ''}');
    _accounts[email] = account;

    return _Reply(200, {
      'ok': true,
      'alreadyVerified': account['emailVerified'] == true,
      'verifyHours': 48,
    });
  }

  /// Always ok, like the backend, so it never says who has an account.
  /// DEMO: no link can be sent, so there is nothing to tap; the password
  /// stays as it is.
  _Reply _forgotPassword(Map<String, dynamic> body) {
    _emailOf(body);

    return const _Reply(200, {
      'ok': true,
      'expiresInMinutes': 30,
      'message': 'DEMO: no email is sent, so no reset link arrives.',
    });
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

  Map<String, dynamic> _profile(String email, Map<String, dynamic> a) => {
        'email': email,
        // Contact information the senior can set in Account; empty until
        // they do, since signing up no longer asks for a number.
        'phone': a['phone'] ?? '',
        'mobile': a['phone'] ?? '',
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
        'hasPhoto': false,
        'photoVersion': '',
      };

  _Reply _updateProfile(
      String email, Map<String, dynamic> a, Map<String, dynamic> body) {
    for (final k in [
      'firstName',
      'middleName',
      'lastName',
      'suffix',
      'noMiddleName',
      'barangay',
      'municipality',
      'province',
      // Contact information now, not a credential.
      'phone',
    ]) {
      if (body.containsKey(k) && body[k] != null) a[k] = body[k];
    }
    final birth = '${body['birthDate'] ?? ''}';
    if (birth.length >= 10) a['birthDate'] = birth.substring(0, 10);
    return _Reply(200, {'ok': true, 'profile': _profile(email, a)});
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
      'purok': 'Purok 3',
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
    // Released by the office; no amounts, like the real backend.
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

  /// The bell list with the account's marks, like the real backend: deleted
  /// messages left out, read ones with "read": true.
  List<Map<String, dynamic>> _notifications(Map<String, dynamic> a) {
    final read = _marks(a, 'read');
    final dismissed = _marks(a, 'dismissed');
    return [
      for (final n in _allNotifications(a))
        if (!dismissed.contains(n['id']))
          {...n, if (read.contains(n['id'])) 'read': true},
    ];
  }

  /// The ids marked "read" or "dismissed" on this account. Kept with the
  /// account, so logging out and in again keeps them.
  Set<String> _marks(Map<String, dynamic> a, String kind) => {
        ...((a['notificationMarks'] as Map?)?[kind] as List? ?? const [])
            .whereType<String>(),
      };

  /// POST /notifications/read, /dismiss and /restore, with the same body
  /// and checks as Mobile\NotificationController: ids not in the account's
  /// list are left out.
  _Reply _markNotifications(
      Map<String, dynamic> a, Map<String, dynamic> body, String kind, bool on) {
    final ids = body['ids'];
    if (ids is! List ||
        ids.isEmpty ||
        ids.length > 200 ||
        ids.any((id) => id is! String || id.isEmpty || id.length > 100)) {
      throw const _Reply(422, {'message': 'The ids field must be a list of message ids.'});
    }
    final own = _allNotifications(a).map((n) => n['id']).toSet();
    final applied = ids.cast<String>().toSet().where(own.contains).toList();
    final marks = _marks(a, kind);
    if (on) {
      marks.addAll(applied);
    } else {
      marks.removeAll(applied);
    }
    a['notificationMarks'] = {
      ...Map<String, dynamic>.from((a['notificationMarks'] as Map?) ?? {}),
      kind: marks.toList(),
    };
    return _Reply(200, {'ok': true, 'ids': applied});
  }

  List<Map<String, dynamic>> _allNotifications(Map<String, dynamic> a) {
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
