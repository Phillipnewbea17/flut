import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_state/accessibility_provider.dart';
import 'app_state/auth/login_flow.dart';
import 'app_state/auth/mpin_reset_flow.dart';
import 'app_state/auth/registration_flow.dart';
import 'app_state/session_provider.dart';
import 'app_state/user_provider.dart';
import 'repositories/application_repository.dart';
import 'repositories/document_repository.dart';
import 'repositories/identity_repository.dart';
import 'repositories/places_repository.dart';
import 'repositories/requests_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/wallet_repository.dart';
import 'routes/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/benefits_service.dart';
import 'services/camera_access.dart';
import 'services/document_service.dart';
import 'services/id_text_reader.dart';
import 'services/identity_service.dart';
import 'services/pension_service.dart';
import 'services/places_service.dart';
import 'services/profile_photo_store.dart';
import 'services/requests_service.dart';
import 'services/sos_service.dart';
import 'services/wallet_service.dart';
import 'storage/document_vault.dart';
import 'storage/local_db.dart';
import 'storage/preferences.dart';
import 'storage/secure_vault.dart';
import 'theme/app_theme.dart';
import 'theme/high_contrast_theme.dart';
import 'utils/image_compressor.dart';
import 'demo/demo_backend.dart'; // DEMO
import 'demo/demo_mode.dart'; // DEMO

/// Start-up only: open storage, build services and providers, run the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage
  final prefs = await Preferences.load();
  const vault = SecureVault();
  final db = await LocalDb.open();
  final documentVault = await DocumentVault.open();

  // Services. Signing in needs the SCMS backend
  // (--dart-define=API_BASE_URL=...). Without it nobody can sign in: there
  // is no demo code and no pretend login.
  // DEMO: --dart-define=DEMO_MODE=true answers on the phone (lib/demo).
  final api = kDemoMode
      ? ApiClient(baseUrl: DemoBackend.baseUrl, client: await DemoBackend.open())
      : ApiClient();
  final AuthService auth = api.isConnected
      ? ApiAuthService(api: api, vault: vault)
      : const UnavailableAuthService();
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
  final requests = RequestsRepository(
    service: RequestsService(api),
    vault: documentVault,
    db: db,
  );
  // Identity checks are made by the SCMS backend only.
  final identity = IdentityRepository(service: ApiIdentityService(api), db: db);

  // App state
  final session = SessionProvider(prefs: prefs, vault: vault, auth: auth);
  final user = UserProvider(prefs);
  final accessibility = await AccessibilityProvider.load(prefs);

  // Sign-in flows. Create Account and Login keep separate business logic;
  // only the code step (OtpChallenge) and the session are shared.
  final registration = RegistrationFlow(auth: auth, session: session);
  final login = LoginFlow(auth: auth, session: session);
  final mpinReset = MpinResetFlow(auth: auth, session: session);

  // After Create Account or Login: remember the number, show the name typed
  // in Create Account right away (Home header, Account > Personal
  // information), then what the server has (the linked senior record wins).
  session.afterSignIn = (phone, name) async {
    await user.confirmPhone(phone);
    if (name != null) await user.applyRegistrationName(name);
    final profile = await identity.refreshFromServer();
    if (profile != null) await user.applyLinkedProfile(profile);
  };

  // The backend refused the session token: back to Login.
  api.onSessionExpired = () => session.expireSession();

  // The app-profile photo, kept on this phone only.
  final photoStore = ProfilePhotoStore();

  // Log out (or an ended session) wipes everything that belongs to the
  // account from this phone. Nothing is deleted on the server.
  session.addLogoutHook(() async {
    await photoStore.clear();
    registration.reset();
    login.reset();
    mpinReset.reset();
    user.reset();
    applications.reset();
    documents.reset();
    wallet.reset();
    users.reset();
    requests.reset();
    identity.reset();
    await db.clear();
    await documentVault.clear();
  });
  await session.init();

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
        ChangeNotifierProvider<RequestsRepository>.value(value: requests),
        ChangeNotifierProvider<IdentityRepository>.value(value: identity),
        Provider<IdTextReader>.value(value: MlKitIdTextReader()),
        Provider<CameraAccess>.value(value: DeviceCameraAccess()),
        Provider<PlacesRepository>.value(value: places),
        Provider<AuthService>.value(value: auth),
        Provider<RegistrationFlow>.value(value: registration),
        Provider<LoginFlow>.value(value: login),
        Provider<MpinResetFlow>.value(value: mpinReset),
        Provider<BenefitsService>.value(value: BenefitsService(api)),
        Provider<PensionService>.value(value: PensionService(api)),
        Provider<SosService>.value(value: SosService()),
        Provider<ImageCompressor>.value(value: ImageCompressor()),
        Provider<ProfilePhotoStore>.value(value: photoStore),
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
  /// Check the session with the backend again after the app was away
  /// this long.
  static const Duration _recheckAfter = Duration(minutes: 5);

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
          DateTime.now().difference(pausedAt) > _recheckAfter) {
        session.recheckSession();
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
          // DEMO: a ribbon on every screen while demo mode is on.
          child: kDemoMode
              ? Banner(
                  message: 'DEMO',
                  location: BannerLocation.topEnd,
                  child: child ?? const SizedBox.shrink(),
                )
              : child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
