import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_state/session_provider.dart';
import '../models/benefit.dart';
import '../models/help_category.dart';
import '../models/onboarding_stage.dart';
import '../models/personal_info.dart';
import '../models/service_request.dart';
import '../views/core_navigation/master_navigation_hub.dart';
import '../views/identity/capture_id_view.dart';
import '../views/identity/identity_verification_view.dart';
import '../views/identity/personal_info_form_view.dart';
import '../views/identity/personal_info_setup_view.dart';
import '../views/identity/scan_id_view.dart';
import '../views/identity/selfie_capture_view.dart';
import '../views/identity/verification_result_view.dart';
import '../views/onboarding/check_inbox_view.dart';
import '../views/onboarding/forgot_password_view.dart';
import '../views/onboarding/login_view.dart';
import '../views/onboarding/register_credentials_view.dart';
import '../views/onboarding/register_name_view.dart';
import '../views/onboarding/splash_loading_view.dart';
import '../views/onboarding/welcome_view.dart';
import '../views/shared/qr_cashier_view.dart';
import '../views/tabs/account/accessibility_view.dart';
import '../views/tabs/account/account_view.dart';
import '../views/tabs/account/change_address_view.dart';
import '../views/tabs/account/change_password_view.dart';
import '../views/tabs/account/change_phone_view.dart';
import '../views/tabs/account/contact_us_view.dart';
import '../views/tabs/account/emergency_contact_view.dart';
import '../views/tabs/account/faq_view.dart';
import '../views/tabs/account/personal_info_view.dart';
import '../views/tabs/account/privacy_notice_view.dart';
import '../views/tabs/account/profile_correction_view.dart';
import '../views/tabs/account/proxy_hub_view.dart';
import '../views/tabs/applications/application_status_view.dart';
import '../views/tabs/applications/applications_view.dart';
import '../views/tabs/applications/assistance_view.dart';
import '../views/tabs/applications/burial_request_form_view.dart';
import '../views/tabs/applications/id_photo_capture_view.dart';
import '../views/tabs/applications/medical_request_form_view.dart';
import '../views/tabs/applications/request_detail_view.dart';
import '../views/tabs/applications/request_history_view.dart';
import '../views/tabs/applications/requests_hub_view.dart';
import '../views/tabs/applications/upload_documents_view.dart';
import '../views/tabs/benefits/benefits_services_view.dart';
import '../views/tabs/benefits/benefits_tab_view.dart';
import '../views/tabs/benefits/senior_calculator_view.dart';
import '../views/tabs/help/help_request_form_view.dart';
import '../views/tabs/help/report_violation_view.dart';
import '../views/tabs/home/announcements_view.dart';
import '../views/tabs/home/home_dashboard_view.dart';
import '../views/tabs/home/notifications_view.dart';
import '../views/tabs/local_guide/local_guide_map_view.dart';
import '../views/tabs/my_id/id_details_view.dart';
import '../views/tabs/my_id/id_replacement_view.dart';
import '../views/tabs/my_id/id_services_view.dart';
import '../views/tabs/my_id/my_id_view.dart';

/// Every screen address in the app.
class Routes {
  Routes._();

  static const String splash = '/splash';

  /// Onboarding: Create Account or Login.
  static const String welcome = '/welcome';

  // Sign up (new user). "/register" opens the first step.
  // name -> email + password + confirm -> check your inbox.
  static const String register = '/register';
  static const String registerName = '/register/name';
  static const String registerCredentials = '/register/credentials';

  // Login (returning user): one screen, email + password.
  static const String login = '/login';

  // Forgot password: one screen. The new password is typed on the page the
  // emailed link opens, which the backend serves, not this app.
  static const String forgotPassword = '/forgot-password';

  /// "Check your inbox", until the emailed link has been tapped. Reached
  /// from Sign up and from a login that was refused as unconfirmed, so it
  /// is one screen for both flows.
  static const String checkInbox = '/check-inbox';

  /// Short addresses that are not a screen themselves -> the first step of
  /// their flow. Login and Forgot password are single screens, so their own
  /// address is where they live and neither needs redirecting.
  static const Map<String, String> flowStarts = {
    register: registerName,
  };

  /// The first screen of each flow.
  static String entryFor(AuthFlow? flow) => switch (flow) {
    AuthFlow.register => registerName,
    AuthFlow.login => login,
    AuthFlow.forgotPassword => forgotPassword,
    null => welcome,
  };

  /// The screen for [stage] in [flow], or null when the stage has none.
  static String? screenFor(OnboardingStage stage, AuthFlow? flow) =>
      switch ((stage, flow)) {
        (OnboardingStage.credentials, AuthFlow.register) =>
        registerCredentials,
        (OnboardingStage.checkInbox, AuthFlow.register) => checkInbox,
        (OnboardingStage.checkInbox, AuthFlow.login) => checkInbox,
        _ => null,
      };

  /// Screens a signed-out user may open: the first step of each flow.
  static const Set<String> signedOut = {
    welcome,
    registerName,
    login,
    forgotPassword,
    contact,
  };

  // Senior citizen record: personal information, then the live selfie.
  // The backend links the account to the SCMS record. (Not part of
  // signing in.)
  static const String personalInfoSetup = '/personal-information/setup';
  static const String scanId = '/personal-information/scan-id';
  static const String captureId = '/personal-information/capture-id';
  static const String manualInfo = '/personal-information/manual';
  static const String reviewInfo = '/personal-information/review';
  static const String identityVerification = '/identity-verification';
  static const String selfie = '/identity-verification/selfie';
  static const String verificationResult = '/identity-verification/result';

  /// Screens of the identity setup. While setup is at that step, these are
  /// the only screens (plus Contact us) the user can open.
  static bool isIdentitySetup(String location) =>
      location.startsWith('/personal-information/') ||
          location == identityVerification ||
          location.startsWith('$identityVerification/');

  // The five bottom-navigation tabs, in order.
  static const String home = '/home';
  static const String applications = '/applications';
  static const String myId = '/my-id';
  static const String benefitsTab = '/benefits';
  static const String account = '/account';
  static const List<String> tabs = [home, applications, myId, benefitsTab, account];

  // Pages opened from the tabs. They cover the tab bar and go back to the
  // tab they were opened from, so any tab can open any page.

  // Home
  static const String notifications = '/notifications';
  static const String announcements = '/announcements';

  // Senior citizen application
  static const String applicationStatus = '/application';
  static const String upload = '/application/upload';
  static const String idPhoto = '/application/upload/id-photo';

  // Requests to the OSCA office
  /// Home "Assistance": choose Medical or Burial.
  static const String assistance = '/assistance';
  static const String medical = '/medical';
  static const String medicalNew = '/medical/new';
  static const String burial = '/burial';
  static const String burialNew = '/burial/new';
  static const String help = '/help';
  static const String helpNew = '/help/new';
  static const String reportViolation = '/help/report-store';
  static const String requests = '/requests';

  /// One request. [justSent] shows the "sent / not sent" message on top.
  static String request(String id, {bool justSent = false}) =>
      '/requests/${Uri.encodeComponent(id)}${justSent ? '?new=1' : ''}';

  /// Help & complaints form, optionally with the concern type chosen.
  static String helpNewFor(HelpCategory category) =>
      '$helpNew?category=${category.name}';

  // Senior ID
  static const String idServices = '/id-services';
  static const String qrCashier = '/id/qr';
  static const String idDetails = '/id/details';
  static const String idReplacement = '/id/replacement';

  // Benefits
  static const String benefits = '/benefits/list';
  static const String calculator = '/benefits/calculator';
  static const String localGuide = '/benefits/local-guide';

  /// Benefits list showing one category (e.g. pension).
  static String benefitsFor(BenefitCategory category) =>
      '$benefits?category=${category.name}';

  // Account
  static const String personalInfo = '/account/personal';

  /// Ask OSCA to correct an official field.
  static String correctionFor(PersonalField field) =>
      '$personalInfo/correction?field=${field.name}';
  static const String correction = '/account/personal/correction';
  static const String address = '/account/address';
  static const String phoneNumber = '/account/phone';
  static const String emergencyContact = '/account/emergency-contact';
  static const String family = '/account/family';
  static const String accessibility = '/account/accessibility';
  static const String faq = '/account/faq';
  static const String privacy = '/account/privacy';
  static const String contact = '/account/contact';

  /// Opened from Account. Not part of setup, so the guard leaves it alone.
  static const String changePassword = '/change-password';

  /// Screens that belong to signing in and setup.
  static const Set<String> onboarding = {
    splash,
    welcome,
    register,
    registerName,
    registerCredentials,
    login,
    forgotPassword,
    checkInbox,
    personalInfoSetup,
    scanId,
    captureId,
    manualInfo,
    reviewInfo,
    identityVerification,
    selfie,
    verificationResult,
  };
}

/// The redirect guard. Given the app's current state, it returns the screen
/// the user MUST be on, or null if they are already in the right place.
/// It is a plain function so it can be tested without any widgets.
///
/// Every screen of the app (Home, Applications, My ID, Benefits, Account,
/// Notifications...) needs [OnboardingStage.completed], which is only
/// reached after Laravel accepted the email and password (Login) or created
/// the account (Create Account) and returned a session.
String? appRedirect({
  required bool splashDone,
  required OnboardingStage stage,
  required AuthFlow? flow,
  required String location,
}) {
  String? goTo(String target) => location == target ? null : target;

  // 1. Splash (which checks the saved session) always comes first.
  if (!splashDone) return goTo(Routes.splash);

  // "/register", "/login", "/forgot-password" start their flow.
  final start = Routes.flowStarts[location];

  // 2. The stage decides the screen.
  switch (stage) {
    case OnboardingStage.signedOut:
      if (start != null) return start;
      if (Routes.signedOut.contains(location)) return null;
      return Routes.entryFor(flow);
    case OnboardingStage.credentials:
    case OnboardingStage.checkInbox:
      return goTo(Routes.screenFor(stage, flow) ?? Routes.welcome);
    case OnboardingStage.identitySetup:
    // Any screen of the setup, and "Contact OSCA" from them.
      if (Routes.isIdentitySetup(location) || location == Routes.contact) {
        return null;
      }
      return Routes.personalInfoSetup;
    case OnboardingStage.completed:
    // 3. Signed in and linked: the app.
      return Routes.onboarding.contains(location) ? Routes.home : null;
  }
}

/// A page with a fixed address.
GoRoute _page(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(path: path, builder: (context, state) => build(state));

/// One bottom-navigation tab.
StatefulShellBranch _tab(String path, Widget view) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => view)],
);

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
        flow: session.flow,
        location: state.matchedLocation,
      ),
      routes: [
        // Signing in
        _page(Routes.splash, (_) => const SplashLoadingView()),
        _page(Routes.welcome, (_) => const WelcomeView()),
        // The redirect sends "/register" to the first step of its flow.
        for (final start in Routes.flowStarts.keys)
          _page(start, (_) => const SizedBox.shrink()),

        // Sign up (new user): name, then email + password + confirm
        _page(Routes.registerName, (_) => const RegisterNameView()),
        _page(Routes.registerCredentials,
                (_) => const RegisterCredentialsView()),

        // Login (returning user): email + password, on one screen
        _page(Routes.login, (_) => const LoginView()),

        // Forgot password: ask for the address; the link does the rest
        _page(Routes.forgotPassword, (_) => const ForgotPasswordView()),

        // Waiting for the emailed link to be tapped (Sign up, or a login
        // refused because the address was never confirmed)
        _page(Routes.checkInbox, (_) => const CheckInboxView()),

        // Senior citizen record
        _page(Routes.personalInfoSetup, (_) => const PersonalInfoSetupView()),
        _page(Routes.scanId, (_) => const ScanIdView()),
        _page(Routes.captureId, (_) => const CaptureIdView()),
        _page(Routes.manualInfo,
                (_) => const PersonalInfoFormView(mode: InfoFormMode.manual)),
        _page(Routes.reviewInfo,
                (_) => const PersonalInfoFormView(mode: InfoFormMode.review)),
        _page(Routes.identityVerification,
                (_) => const IdentityVerificationView()),
        _page(Routes.selfie, (_) => const SelfieCaptureView()),
        _page(Routes.verificationResult,
                (_) => const VerificationResultView()),
        _page(Routes.changePassword, (_) => const ChangePasswordView()),

        // The app: Home | Applications | My ID | Benefits | Account.
        // indexedStack keeps every tab alive, so scrolling and typing are
        // not lost when switching tabs.
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              MasterNavigationHub(navigationShell: shell),
          branches: [
            _tab(Routes.home, const HomeDashboardView()),
            _tab(Routes.applications, const ApplicationsView()),
            _tab(Routes.myId, const MyIdView()),
            _tab(Routes.benefitsTab, const BenefitsTabView()),
            _tab(Routes.account, const AccountView()),
          ],
        ),

        // Home
        _page(Routes.notifications, (_) => const NotificationsView()),
        _page(Routes.announcements, (_) => const AnnouncementsView()),

        // Senior citizen application
        _page(Routes.applicationStatus, (_) => const ApplicationStatusView()),
        _page(Routes.upload, (_) => const UploadDocumentsView()),
        _page(Routes.idPhoto, (_) => const IdPhotoCaptureView()),

        // Requests to the OSCA office
        _page(Routes.assistance, (_) => const AssistanceView()),
        _page(Routes.medical,
                (_) => const RequestsHubView(kind: RequestKind.medical)),
        _page(Routes.medicalNew, (_) => const MedicalRequestFormView()),
        _page(Routes.burial,
                (_) => const RequestsHubView(kind: RequestKind.burial)),
        _page(Routes.burialNew, (_) => const BurialRequestFormView()),
        _page(Routes.help, (_) => const RequestsHubView(kind: RequestKind.help)),
        _page(
          Routes.helpNew,
              (state) => HelpRequestFormView(
            category: HelpCategoryInfo.parse(
              state.uri.queryParameters['category'],
            ),
          ),
        ),
        _page(Routes.reportViolation, (_) => const ReportViolationView()),
        _page(Routes.requests, (_) => const RequestHistoryView()),
        _page(
          '${Routes.requests}/:id',
              (state) => RequestDetailView(
            id: state.pathParameters['id'] ?? '',
            justSent: state.uri.queryParameters['new'] == '1',
          ),
        ),

        // Senior ID
        _page(Routes.idServices, (_) => const IdServicesView()),
        _page(Routes.qrCashier, (_) => const QrCashierView()),
        _page(Routes.idDetails, (_) => const IdDetailsView()),
        _page(Routes.idReplacement, (_) => const IdReplacementView()),

        // Benefits
        _page(
          Routes.benefits,
              (state) => BenefitsServicesView(
            initialFilter: BenefitCategoryInfo.tryParse(
              state.uri.queryParameters['category'],
            ),
          ),
        ),
        _page(Routes.calculator, (_) => const SeniorCalculatorView()),
        _page(Routes.localGuide, (_) => const LocalGuidePage()),

        // Account
        _page(Routes.personalInfo, (_) => const PersonalInfoView()),
        _page(
          Routes.correction,
              (state) => ProfileCorrectionView(
            initialField:
            PersonalFieldInfo.tryParse(state.uri.queryParameters['field']),
          ),
        ),
        _page(Routes.address, (_) => const ChangeAddressView()),
        _page(Routes.phoneNumber, (_) => const ChangePhoneView()),
        _page(Routes.emergencyContact, (_) => const EmergencyContactView()),
        _page(Routes.family, (_) => const ProxyHubView()),
        _page(Routes.accessibility, (_) => const AccessibilityView()),
        _page(Routes.faq, (_) => const FaqView()),
        _page(Routes.privacy, (_) => const PrivacyNoticeView()),
        _page(Routes.contact, (_) => const ContactUsView()),
      ],
    );
  }
}
