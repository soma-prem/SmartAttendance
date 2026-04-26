# Smart Attendance

Smart Attendance is a Flutter + Firebase app for managing classroom attendance with separate **Admin**, **Faculty**, and **Student** flows.

## Features
- Semester-based timetable management (Mon–Sat)
- Faculty attendance marking
- Student dashboard with subject-wise + overall attendance
- Attendance disputes workflow
- Push notifications (FCM) + local notifications
- Basic exports (PDF/open file) utilities

## Tech Stack
- Flutter (Dart)
- Firebase: Auth, Firestore, Cloud Messaging

## Setup (Firebase)
1. Install dependencies: `flutter pub get`
2. Configure Firebase (recommended via FlutterFire CLI):
   - Run `flutterfire configure` to generate `lib/firebase_options.dart` and platform configs
3. Make sure your platform config files exist locally:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
   - macOS (if used): `macos/Runner/GoogleService-Info.plist`
4. Run the app: `flutter run`

## Secrets / Keys (Important)
This repo is prepared for GitHub so secrets are **ignored by default**:
- Firebase configs: `google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart`
- Service accounts and private keys (including anything inside `secrets/`)
- `.env` files and Android signing keys

Put local-only secret files in `secrets/` and follow `secrets/README.md`.

## Documentation
- `QUICK_START_GUIDE.md`
- `FEATURES_DOCUMENTATION.md`

## Security Note
This is an educational/mini-project. Review the auth/storage approach before using in production (e.g., do not store raw passwords in Firestore).
