import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_state/accessibility_provider.dart';
import 'app_state/session_provider.dart';
import 'app_state/user_provider.dart';
import 'repositories/application_repository.dart';
import 'repositories/document_repository.dart';
import 'repositories/places_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/wallet_repository.dart';
import 'routes/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/benefits_service.dart';
import 'services/document_service.dart';
import 'services/places_service.dart';
import 'services/sos_service.dart';
import 'services/wallet_service.dart';
import 'storage/document_vault.dart';
import 'storage/local_db.dart';
import 'storage/preferences.dart';
import 'storage/secure_vault.dart';
import 'theme/app_theme.dart';
import 'theme/high_contrast_theme.dart';
import 'utils/image_compressor.dart';

/// Start-up only: open storage, build services and providers, run the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage
  final prefs = await Preferences.load();
  const vault = SecureVault();
  final db = await LocalDb.open();
  final documentVault = await DocumentVault.open();

  // Services. Without --dart-define=API_BASE_URL=... the app uses the fake
  // server (see services/api_client.dart) and the demo code 9109.
  final api = ApiClient();
  final AuthService auth = api.isConnected
      ? ApiAuthService(api: api, vault: vault)
      : FakeAuthService();
  if (api.isConnected) {
    try {
      api.token = await vault.readToken();
    } catch (_) {
      // Secure storage unreadable: the user signs in again.
    }
  }

  // Repositories
  final applications = ApplicationRepository(api: api, db: db);
  final documents = DocumentRepository(
    service: DocumentService(api),
    vault: documentVault,
    db: db,
  );
  final wallet = WalletRepository(service: WalletService(api), db: db);
  final places = PlacesRepository(service: PlacesService(api), db: db);
  final users = UserRepository(api: api, db: db);

  // App state
  final session = SessionProvider(prefs: prefs, vault: vault);
  await session.init();
  final user = UserProvider(prefs);
  final accessibility = await AccessibilityProvider.load(prefs);

  // Log out wipes everything that belongs to the account.
  session.addLogoutHook(() async {
    if (api.isConnected && api.token != null) {
      try {
        await api.post('/auth/sign-out', const {});
      } catch (_) {
        // Offline: the token is still forgotten on this phone below.
      }
    }
    api.token = null;
    user.reset();
    applications.reset();
    documents.reset();
    wallet.reset();
    users.reset();
    await db.clear();
    await documentVault.clear();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>.value(value: session),
        ChangeNotifierProvider<UserProvider>.value(value: user),
        ChangeNotifierProvider<AccessibilityProvider>.value(
          value: accessibility,
        ),
        ChangeNotifierProvider<ApplicationRepository>.value(
          value: applications,
        ),
        ChangeNotifierProvider<DocumentRepository>.value(value: documents),
        ChangeNotifierProvider<WalletRepository>.value(value: wallet),
        ChangeNotifierProvider<UserRepository>.value(value: users),
        Provider<PlacesRepository>.value(value: places),
        Provider<AuthService>.value(value: auth),
        Provider<BenefitsService>.value(value: BenefitsService(api)),
        Provider<SosService>.value(value: SosService()),
        Provider<ImageCompressor>.value(value: ImageCompressor()),
      ],
      child: const SeniorCompanionApp(),
    ),
  );
}

class SeniorCompanionApp extends StatefulWidget {
  const SeniorCompanionApp({super.key});

  @override
  State<SeniorCompanionApp> createState() => _SeniorCompanionAppState();
}

class _SeniorCompanionAppState extends State<SeniorCompanionApp>
    with WidgetsBindingObserver {
  /// Ask for the MPIN again after the app was away this long.
  static const Duration _autoLockAfter = Duration(minutes: 5);

  late final GoRouter _router;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    // The router is built once, so it is not reset when the app rebuilds.
    _router = AppRouter.create(context.read<SessionProvider>());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt == null) return;
      final session = context.read<SessionProvider>();
      if (session.onboardingComplete &&
          DateTime.now().difference(pausedAt) > _autoLockAfter) {
        session.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessibilityProvider>();

    return MaterialApp.router(
      title: 'SeniorCompanion',
      debugShowCheckedModeBanner: false,
      theme: access.highContrast ? HighContrastTheme.light() : AppTheme.light(),
      routerConfig: _router,
      builder: (context, child) {
        // Apply the user's text size and high contrast to every screen.
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(1);
        final scale =
            (systemScale * access.textScale).clamp(1.0, 1.8).toDouble();
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(scale),
            boldText: media.boldText || access.highContrast,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
