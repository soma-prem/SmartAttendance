Put secret files here locally (do not commit).

- Anything inside `secrets/` is ignored by `.gitignore` (except this README).
- Place the Google Service Account JSON here (example names):
  - `secrets/serviceAccount.json`
  - `secrets/serviceAccountKey.json`
- Do NOT include a service account JSON inside the Flutter app bundle; it can be extracted from APK/IPA.
