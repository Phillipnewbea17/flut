import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_state/session_provider.dart';
import '../models/onboarding_stage.dart';
import '../views/core_navigation/master_navigation_hub.dart';
import '../views/onboarding/emergency_setup_view.dart';
import '../views/onboarding/mpin_view.dart';
import '../views/onboarding/onboarding_carousel.dart';
import '../views/onboarding/otp_verify_view.dart';
import '../views/onboarding/phone_entry_view.dart';
import '../views/onboarding/role_selection_view.dart';
import '../views/onboarding/splash_loading_view.dart';
import '../views/shared/qr_cashier_view.dart';
import '../views/tabs/account/accessibility_view.dart';
import '../views/tabs/account/change_address_view.dart';
import '../views/tabs/account/contact_us_view.dart';
import '../views/tabs/account/emergency_contact_view.dart';
import '../views/tabs/account/faq_view.dart';
import '../views/tabs/account/personal_info_view.dart';
import '../views/tabs/account/privacy_notice_view.dart';
import '../views/tabs/home/announcements_view.dart';
import '../views/tabs/home/application_progress_view.dart';
import '../views/tabs/home/notifications_view.dart';
import '../views/tabs/home/tiles/benefits_services_view.dart';
import '../views/tabs/home/tiles/id_photo_capture_view.dart';
import '../views/tabs/home/tiles/proxy_hub_view.dart';
import '../views/tabs/home/tiles/report_violation_view.dart';
import '../views/tabs/home/tiles/senior_calculator_view.dart';
import '../views/tabs/home/tiles/upload_documents_view.dart';

/// Every screen address in the app.
class Routes {
  Routes._();

  // Login / setup
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String phone = '/phone';
  static const String otp = '/otp';
  static const String mpin = '/mpin';
  static const String role = '/role';
  static const String emergency = '/emergency';

  // The app (4 tabs) and the pages opened from it
  static const String home = '/home';
  static const String progress = '/home/progress';
  static const String announcements = '/home/announcements';
  static const String notifications = '/home/notifications';
  static const String calculator = '/home/calculator';
  static const String upload = '/home/upload';
  static const String idPhoto = '/home/upload/id-photo';
  static const String benefits = '/home/benefits';
  static const String reportViolation = '/home/report';
  static const String family = '/home/family';
  static const String qrCashier = '/home/qr';
  static const String personalInfo = '/home/personal';
  static const String address = '/home/address';
  static const String emergencyContact = '/home/emergency-contact';
  static const String accessibility = '/home/accessibility';
  static const String faq = '/home/faq';
  static const String privacy = '/home/privacy';
  static const String contact = '/home/contact';

  /// Opened from Account. Not part of setup, so the guard leaves it alone.
  static const String changeMpin = '/change-mpin';

  /// Screens that belong to the login / setup flow.
  static const Set<String> onboarding = {
    splash,
    welcome,
    phone,
    otp,
    mpin,
    role,
    emergency,
  };
}

/// The redirect guard. Given the app's current state, it returns the screen
/// the user MUST be on, or null if they are already in the right place.
/// It is a plain function so it can be tested without any widgets.
String? appRedirect({
  required bool splashDone,
  required OnboardingStage stage,
  required bool unlocked,
  required String location,
}) {
  String? goTo(String target) => location == target ? null : target;

  // 1. Splash always comes first.
  if (!splashDone) return goTo(Routes.splash);

  // 2. During setup, the saved stage decides the screen.
  switch (stage) {
    case OnboardingStage.splash:
    case OnboardingStage.welcome:
      return goTo(Routes.welcome);
    case OnboardingStage.phoneEntry:
      return goTo(Routes.phone);
    case OnboardingStage.otpVerify:
      return goTo(Routes.otp);
    case OnboardingStage.mpinSetup:
      return goTo(Routes.mpin);
    case OnboardingStage.roleSelection:
      return goTo(Routes.role);
    case OnboardingStage.emergencySetup:
      return goTo(Routes.emergency);
    case OnboardingStage.completed:
    // 3. Setup is done: the MPIN gate, then the app.
      if (!unlocked) return goTo(Routes.mpin);
      return Routes.onboarding.contains(location) ? Routes.home : null;
  }
}

/// Last part of a path, for nested routes: "/home/progress" -> "progress".
String _child(String fullPath, String parent) =>
    fullPath.substring(parent.length + 1);

class AppRouter {
  AppRouter._();

  static GoRouter create(SessionProvider session) {
    return GoRouter(
      initialLocation: Routes.splash,
      // Re-run the redirect every time the session changes.
      refreshListenable: session,
      redirect: (context, state) => appRedirect(
        splashDone: session.splashDone,
        stage: session.stage,
        unlocked: session.unlocked,
        location: state.matchedLocation,
      ),
      routes: [
        GoRoute(
          path: Routes.splash,
          builder: (context, state) => const SplashLoadingView(),
        ),
        GoRoute(
          path: Routes.welcome,
          builder: (context, state) => const OnboardingCarousel(),
        ),
        GoRoute(
          path: Routes.phone,
          builder: (context, state) => const PhoneEntryView(),
        ),
        GoRoute(
          path: Routes.otp,
          builder: (context, state) => const OtpVerifyView(),
        ),
        GoRoute(
          path: Routes.mpin,
          builder: (context, state) {
            // Setup in progress = create a new MPIN. Otherwise = enter it.
            final mode = session.stage == OnboardingStage.mpinSetup
                ? MpinMode.create
                : MpinMode.enter;
            return MpinView(key: ValueKey(mode), mode: mode);
          },
        ),
        GoRoute(
          path: Routes.role,
          builder: (context, state) => const RoleSelectionView(),
        ),
        GoRoute(
          path: Routes.emergency,
          builder: (context, state) => const EmergencySetupView(),
        ),
        GoRoute(
          path: Routes.changeMpin,
          builder: (context, state) => const MpinView(mode: MpinMode.change),
        ),
        GoRoute(
          path: Routes.home,
          builder: (context, state) => const MasterNavigationHub(),
          routes: [
            GoRoute(
              path: _child(Routes.progress, Routes.home),
              builder: (context, state) => const ApplicationProgressView(),
            ),
            GoRoute(
              path: _child(Routes.announcements, Routes.home),
              builder: (context, state) => const AnnouncementsView(),
            ),
            GoRoute(
              path: _child(Routes.notifications, Routes.home),
              builder: (context, state) => const NotificationsView(),
            ),
            GoRoute(
              path: _child(Routes.calculator, Routes.home),
              builder: (context, state) => const SeniorCalculatorView(),
            ),
            GoRoute(
              path: _child(Routes.upload, Routes.home),
              builder: (context, state) => const UploadDocumentsView(),
              routes: [
                GoRoute(
                  path: _child(Routes.idPhoto, Routes.upload),
                  builder: (context, state) => const IdPhotoCaptureView(),
                ),
              ],
            ),
            GoRoute(
              path: _child(Routes.benefits, Routes.home),
              builder: (context, state) => const BenefitsServicesView(),
            ),
            GoRoute(
              path: _child(Routes.reportViolation, Routes.home),
              builder: (context, state) => const ReportViolationView(),
            ),
            GoRoute(
              path: _child(Routes.family, Routes.home),
              builder: (context, state) => const ProxyHubView(),
            ),
            GoRoute(
              path: _child(Routes.qrCashier, Routes.home),
              builder: (context, state) => const QrCashierView(),
            ),
            GoRoute(
              path: _child(Routes.personalInfo, Routes.home),
              builder: (context, state) => const PersonalInfoView(),
            ),
            GoRoute(
              path: _child(Routes.address, Routes.home),
              builder: (context, state) => const ChangeAddressView(),
            ),
            GoRoute(
              path: _child(Routes.emergencyContact, Routes.home),
              builder: (context, state) => const EmergencyContactView(),
            ),
            GoRoute(
              path: _child(Routes.accessibility, Routes.home),
              builder: (context, state) => const AccessibilityView(),
            ),
            GoRoute(
              path: _child(Routes.faq, Routes.home),
              builder: (context, state) => const FaqView(),
            ),
            GoRoute(
              path: _child(Routes.privacy, Routes.home),
              builder: (context, state) => const PrivacyNoticeView(),
            ),
            GoRoute(
              path: _child(Routes.contact, Routes.home),
              builder: (context, state) => const ContactUsView(),
            ),
          ],
        ),
      ],
    );
  }
}