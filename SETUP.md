# SeniorCompanion: setup

## 1. Copy into your Flutter project
Copy `lib/`, `test/`, `assets/` and `pubspec.yaml` into your project folder
and replace the old files. Keep your own `android/` and `ios/` folders.
Delete `test/widget_test.dart` if your project still has it.

Then run:

    flutter pub get
    flutter test
    flutter run

## 2. Android: add these to android/app/src/main/AndroidManifest.xml
Inside `<manifest>` and above `<application>`:

    <uses-permission android:name="android.permission.INTERNET"/>
    <queries>
      <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
      <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>
      <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
      <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
    </queries>

INTERNET is needed for the map in release builds. The queries let the
SOS, Call, Text, Email and Directions buttons open other apps.

## 3. iOS (only if you build for iPhone): ios/Runner/Info.plist

    <key>NSCameraUsageDescription</key>
    <string>To take photos of your papers and your ID photo.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>To choose photos of your papers.</string>
    <key>LSApplicationQueriesSchemes</key>
    <array><string>tel</string><string>sms</string><string>mailto</string></array>

## 4. Test logins
- Mobile number: any 10-digit number starting with 9
- Code: 9109
- MPIN: any 4 numbers that are not easy to guess (not 1234 or 1111)

## 5. Connect to the SCMS backend (Laravel)
Announcements come from the SCMS admin panel
(`ella-proj/scms-backend`, endpoint `GET /api/mobile/announcements`).

1. Start MySQL in XAMPP, then in the backend folder run:

       php artisan serve --host=0.0.0.0 --port=8000

2. Run the app with the backend address:
   - Android emulator:
     `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
   - Real phone on the same Wi-Fi: use your PC's IP from `ipconfig`,
     e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000`,
     and allow port 8000 through Windows Firewall.

Plain `flutter run` (no API_BASE_URL) uses only the files below.

## 6. The app's data (offline seed files)
`lib/services/api_client.dart` answers from the files in `assets/data/`
for everything the backend does not serve yet.
Edit them to change what the app shows:

- `application.json`: application status ("notStarted", "submitted",
  "review", "needsAction" or "approved")
- `announcements.json`, `notifications.json`, `benefits.json`
- `places.json`: Local Guide places. The coordinates are approximate,
  so replace them with your verified list.
- `wallet.json`: the digital Senior ID. It is `null` until approved. To
  see the ID card and the cashier QR code, change it to:

      {
        "seniorId": {
          "idNumber": "UBY-2026-00128",
          "fullName": "Rosela Mabuhay",
          "birthDate": "1958-03-14",
          "address": "Poblacion, Ubay, Bohol",
          "issuedBy": "OSCA Ubay",
          "issuedAt": "2026-10-10"
        }
      }

After editing a file in `assets/data/`, stop the app and run it again.
Pull down on a screen to refresh.

## 7. Before release
- `views/tabs/account/contact_us_view.dart`: add the OSCA phone and email.
- `views/tabs/local_guide/local_guide_map_view.dart`: set
  `_userAgentPackageName` to your app id.
- `views/tabs/account/privacy_notice_view.dart`: replace it with the
  official privacy notice.
- `lib/l10n/app_fil.arb` and `app_ceb.arb`: have a native speaker
  check the translations.
- `main.dart`: replace `FakeAuthService` with your real login service.
