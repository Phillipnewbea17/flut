import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_senior_app/app_state/accessibility_provider.dart';
import 'package:my_senior_app/app_state/session_provider.dart';
import 'package:my_senior_app/app_state/user_provider.dart';
import 'package:my_senior_app/models/onboarding_stage.dart';
import 'package:my_senior_app/models/user_profile.dart';
import 'package:my_senior_app/repositories/application_repository.dart';
import 'package:my_senior_app/repositories/document_repository.dart';
import 'package:my_senior_app/repositories/identity_repository.dart';
import 'package:my_senior_app/repositories/places_repository.dart';
import 'package:my_senior_app/repositories/requests_repository.dart';
import 'package:my_senior_app/repositories/user_repository.dart';
import 'package:my_senior_app/repositories/wallet_repository.dart';
import 'package:my_senior_app/routes/app_router.dart';
import 'package:my_senior_app/services/api_client.dart';
import 'package:my_senior_app/services/benefits_service.dart';
import 'package:my_senior_app/services/identity_service.dart';
import 'package:my_senior_app/services/document_service.dart';
import 'package:my_senior_app/services/pension_service.dart';
import 'package:my_senior_app/services/places_service.dart';
import 'package:my_senior_app/services/requests_service.dart';
import 'package:my_senior_app/services/sos_service.dart';
import 'package:my_senior_app/services/wallet_service.dart';
import 'package:my_senior_app/storage/document_vault.dart';
import 'package:my_senior_app/storage/local_db.dart';
import 'package:my_senior_app/storage/preferences.dart';
import 'package:my_senior_app/storage/auth_storage.dart';
import 'package:my_senior_app/theme/app_theme.dart';
import 'package:my_senior_app/utils/image_compressor.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_auth_backend.dart';

/// The app's private folders, in a temp folder for the test.
class _TempPaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TempPaths(this.dir);
  final Directory dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

/// Boots the real router and providers with no backend (bundled data files
/// only), and a session the backend accepted. ApiClient now defaults to
/// [ApiClient.permanentBaseUrl] so `flutter run` reaches the backend with no
/// flags, so the empty address is passed explicitly here -
/// these tests cover what a senior sees when the office cannot be reached.
Future<GoRouter> _startApp(WidgetTester tester, {double textScale = 1}) async {
  late GoRouter router;
  await tester.runAsync(() async {
    final temp = await Directory.systemTemp.createTemp('scms_smoke');
    addTearDown(() => temp.delete(recursive: true));
    PathProviderPlatform.instance = _TempPaths(temp);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final prefs = await Preferences.load();
    await prefs.saveProfile(const UserProfile(
      phone: '9171234567',
      fullName: 'Analyn Santos',
      role: UserRole.senior,
      municipality: 'Ubay',
      province: 'Bohol',
    ));
    final db = await LocalDb.open();
    final vault = await DocumentVault.open();
    final api = ApiClient(baseUrl: '', latency: Duration.zero);

    // Signed in and linked: a session the backend accepts.
    await prefs.setStage(OnboardingStage.completed);
    await const AuthStorage().saveToken('1|test');
    final backend = FakeAuthBackend()..sessionEmail = 'ana@example.com';
    final session = SessionProvider(
        prefs: prefs, storage: const AuthStorage(), auth: backend);
    await session.init();
    await session.finishSplash();
    expect(session.stage, OnboardingStage.completed);

    router = AppRouter.create(session);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: session),
          ChangeNotifierProvider.value(
            value: IdentityRepository(service: ApiIdentityService(api), db: db),
          ),
          ChangeNotifierProvider.value(value: UserProvider(prefs)),
          ChangeNotifierProvider.value(
              value: await AccessibilityProvider.load(prefs)),
          ChangeNotifierProvider.value(
              value: ApplicationRepository(api: api, db: db)),
          ChangeNotifierProvider.value(
            value: DocumentRepository(
                service: DocumentService(api), vault: vault, db: db),
          ),
          ChangeNotifierProvider.value(
              value: WalletRepository(service: WalletService(api), db: db)),
          ChangeNotifierProvider.value(value: UserRepository(api: api, db: db)),
          ChangeNotifierProvider.value(
            value: RequestsRepository(
                service: RequestsService(api), vault: vault, db: db),
          ),
          Provider.value(
              value: PlacesRepository(service: PlacesService(api), db: db)),
          Provider.value(value: BenefitsService(api)),
          Provider.value(value: PensionService(api)),
          Provider.value(value: SosService()),
          Provider.value(value: ImageCompressor()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
  });
  await _settle(tester);
  return router;
}

/// Lets file reads (real I/O) and the seed-file waits (fake time) finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('five tabs, Home order, and every new page opens', (tester) async {
    // A small phone.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = await _startApp(tester);
    expect(tester.takeException(), isNull);

    // Home: header, Application Status, then the four Quick actions.
    expect(find.textContaining('Analyn'), findsOneWidget);
    expect(find.text('Application Status'), findsOneWidget);
    expect(find.text('You have not submitted an application yet.'),
        findsOneWidget);
    for (final tile in [
      'Upload Documents',
      'Assistance',
      'Help & Complaints',
      'ID Services',
    ]) {
      expect(find.text(tile), findsOneWidget, reason: tile);
    }
    expect(find.text('Senior calculator'), findsNothing);

    // The bottom bar: exactly these five tabs, in this order.
    final labels = ['Home', 'Applications', 'My ID', 'Benefits', 'Account'];
    final xs = [
      for (final l in labels) tester.getCenter(find.text(l).last).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));

    final tabTitles = {
      'Applications': 'My application',
      'My ID': 'My Senior Citizen ID',
      'Benefits': 'My pension',
      'Account': 'Personal information',
    };
    for (final entry in tabTitles.entries) {
      await tester.tap(find.text(entry.key).last);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: entry.key);
      expect(find.textContaining(entry.value, findRichText: true), findsWidgets,
          reason: entry.key);
    }

    // Every page opened from the tabs builds without errors.
    for (final page in [
      Routes.applicationStatus,
      Routes.upload,
      Routes.assistance,
      Routes.medical,
      Routes.medicalNew,
      Routes.burial,
      Routes.burialNew,
      Routes.help,
      Routes.helpNew,
      Routes.reportViolation,
      Routes.requests,
      Routes.idServices,
      Routes.qrCashier,
      Routes.idDetails,
      Routes.idReplacement,
      Routes.benefits,
      Routes.calculator,
      Routes.notifications,
      Routes.announcements,
      Routes.family,
    ]) {
      router.push(page);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: page);
      router.pop();
      await _settle(tester);
    }

    // Back on the tab we left (Account), with the tab bar.
    expect(find.text('Personal information'), findsOneWidget);
  });

  testWidgets('a help request without a backend is saved, never "sent"',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = await _startApp(tester);
    router.push(Routes.helpNew);
    await _settle(tester);

    // Details: 3 steps; Next waits for a concern.
    for (final name in ['Details', 'Photos', 'Review']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.text('Choose one to continue'), findsOneWidget);
    await tester.tap(find.text('Tap to choose'));
    await _settle(tester);
    expect(find.text('Late payment or wrong amount'), findsOneWidget);
    await tester.tap(find.text('Pension'));
    await _settle(tester);
    expect(find.text('Choose one to continue'), findsNothing);
    expect(find.text('e.g. My pension for July is late'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last,
        'When is the next pension release in Ubay?');
    await tester.tap(find.text('NEXT'));
    await _settle(tester);
    // Photos: skip.
    await tester.tap(find.text('NEXT'));
    await _settle(tester);

    // Review: the concern first, with Edit.
    expect(find.text('Concern'), findsOneWidget);
    expect(find.text('Pension'), findsOneWidget);
    expect(find.text('Edit'), findsWidgets);
    await tester.scrollUntilVisible(
        find.text('Not connected to the OSCA office yet'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Not connected to the OSCA office yet'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('SAVE ON THIS PHONE'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Saved, but NOT sent'), findsOneWidget);
    expect(find.text('No reference number yet'), findsOneWidget);
    expect(find.text('Request sent'), findsNothing);
  });

  testWidgets('tabs and pages fit the biggest text size', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The most AccessibilityProvider allows (see main.dart).
    final router = await _startApp(tester, textScale: 1.8);
    expect(tester.takeException(), isNull);
    for (final tab in Routes.tabs) {
      router.go(tab);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: tab);
    }
    for (final page in [
      Routes.applicationStatus,
      Routes.upload,
      Routes.medical,
      Routes.medicalNew,
      Routes.idServices,
      Routes.requests,
    ]) {
      router.push(page);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: page);
      router.pop();
      await _settle(tester);
    }
  });
}
