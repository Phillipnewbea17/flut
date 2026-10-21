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

## 4. Signing in
Signing in needs the SCMS backend (section 5). There is no demo code and
no pretend login: without `API_BASE_URL`, Create Account and Login say
"Signing in is not available right now".

- Create Account: mobile number -> 4-digit code -> create + confirm a
  4-digit MPIN -> match the senior citizen record -> Home
- Login: mobile number -> 4-digit code -> 4-digit MPIN -> Home
- Forgot MPIN: mobile number -> 4-digit code -> new MPIN -> Login

While developing, the code is in the backend's `storage/logs/laravel.log`
(`SMS_DRIVER=log`, refused when `APP_ENV=production`). In production set
`SMS_DRIVER=semaphore` and `SEMAPHORE_API_KEY`. The MPIN must not be easy
to guess (not 1234, 1111...) and not the same as the code.

The MPIN is never saved on the phone. The backend stores it hashed
(bcrypt), never logs it and never sends it back. Older builds saved it on
the phone in plain text; the app deletes that copy on start.

### Sign-in routes (`/api/mobile`, Mobile\AuthController)
Errors are `{"message": "...", "code": "..."}`; the app shows its own
wording for each `code`, never the server's text.

| Route | Body | Answer |
|---|---|---|
| `POST /auth/code` | `phone`, `purpose`: `register`, `login` or `reset_mpin` | `{"expiresIn": 300, "resendIn": 60}` |
| `POST /auth/verify` | `phone`, `code`, `purpose` | `{"verificationToken": "..."}`: 10 minutes, one use, only for that purpose. Not a session. |
| `POST /auth/register` | `phone`, `verificationToken`, `mpin` | `{"token": "..."}`. Creates the account. |
| `POST /auth/login` | `phone`, `verificationToken`, `mpin` | `{"token": "..."}` |
| `POST /auth/mpin/reset` | `phone`, `verificationToken`, `mpin` | `{"ok": true}`. Signs out everywhere; does not sign in. |
| `POST /auth/mpin/change` (signed in) | `currentMpin`, `mpin` | `{"ok": true}` |
| `POST /auth/sign-out` (signed in) | | |

Limits: codes are random, stored hashed, last 5 minutes, 5 wrong tries;
one new code per minute and 5 per hour per number; 5 wrong MPINs lock the
account for 15 minutes (Forgot MPIN unlocks it). Tokens from the old
code-only sign-in are refused, so those users log in again.

### Linking the senior citizen record
After Create Account the senior gives their Senior Citizen / OSCA ID
number, name and birthday (scanned, read from a photo of the ID, or
typed) and takes a live selfie (`POST /identity/verify`). The backend
checks that the ID number, name and birthday match an existing record.
No record is ever created by the app.

The records have no photo to compare a selfie with, and no face-matching
service is configured, so the selfie is checked by OSCA staff: admin web
app > **App Account Verification**. "Same person: link account" links the
app account to the record; "Reject" (with a reason) lets the senior try
again. Until then the app shows "Waiting for the OSCA office", and the
services below answer `not_linked`.

## 5. Connect to the SCMS backend (Laravel)
Everything about the user comes from the SCMS backend
(`ella-proj/scms-backend`, routes `/api/mobile/*`). Without a backend
address the app sends nothing and pretends nothing.

| App | Route | Web module |
|---|---|---|
| Profile | `GET/POST /profile` | Records (the linked record is the source of truth) |
| Notifications | `GET /notifications` | built from the account's own records |
| Announcements | `GET /announcements` | Announcements |
| Senior Citizen application | `POST /documents`, `POST /application/submit`, `GET /application` | Document Verification (source "App") |
| Medical assistance * | `GET/POST /medical-requests` | Medical (source "App") |
| Burial assistance * | `GET/POST /burial-requests` | Burial (source "App") |
| Help & complaints * | `GET/POST /help-requests` | Help & Complaint Desk (source "App") |
| ID replacement * | `GET/POST /senior-id/replacement-requests` | OSCA IDs (replacement source "App") |
| Photos with a request * | `POST {route}/{reference}/attachments` | staff: `GET /api/request-attachments` |
| My ID * | `GET /wallet` | OSCA IDs |
| My pension * | `GET /pension` | Pension |

\* Only for an account linked to its senior record. The app only ever
gets the account's own records, and only what is meant for the senior
(status, dates and the office's answer; no staff notes or amounts).

Only the places list is read from `assets/data/` (reference content
shipped with the app; the backend has no tables for it).

`GET /application` may also send per-paper results, so the app can
say which paper needs fixing (`DocumentReview` in
`lib/models/document_item.dart`):

    "documents": [{"type": "proofOfResidence", "status": "needsCorrection",
                   "note": "The photo is blurred.", "reviewedAt": "..."}]

Without it, the app shows the office's note for the whole application.

1. Start MySQL in XAMPP, then in the backend folder run:

       php artisan migrate
       php artisan serve --host=0.0.0.0 --port=8000

2. Run the app with the backend address:
   - Android emulator:
     `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
   - Real phone on the same Wi-Fi: use your PC's IP from `ipconfig`,
     e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000`,
     and allow port 8000 through Windows Firewall.

Plain `flutter run` (no API_BASE_URL) uses only the files below.

## 6. Guides shipped with the app
Only this file in `assets/data/` is read by the app:

- `places.json`: Local Guide places. The coordinates are approximate,
  so replace them with your verified list.

Everything else (application status, notifications, announcements, the
Senior ID) comes from the backend. After editing a file, stop the app
and run it again.

## 7. Before release
- `views/tabs/account/contact_us_view.dart`: add the OSCA phone and email.
- `views/tabs/local_guide/local_guide_map_view.dart`: set
  `_userAgentPackageName` to your app id.
- `views/tabs/account/privacy_notice_view.dart`: replace it with the
  official privacy notice.
- `lib/l10n/app_fil.arb` and `app_ceb.arb`: have a native speaker
  check the translations.
- Use an `https://` `API_BASE_URL`: the MPIN and the code are sent to it.
