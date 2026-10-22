# BuildFlow — PROGRESS

## How to Run
```bash
flutter run          # on connected Xiaomi device
flutter analyze      # check for errors
```

Demo credentials (FakeAuthRepository):
- Owner: `owner@buildflow.kg` / `123456`
- Foreman: `foreman1@buildflow.kg` / `123456`

---

## Stage 0 — Recon ✅

### Critical Bug
- **Infinite loading on splash screen** — `restoreSession()` calls `flutter_secure_storage.readUserId()` without timeout or try/catch. On Xiaomi and some Android devices this can hang indefinitely. The auth state stays `AuthStatus.initial` and the splash screen never navigates.

### Issues Found (sorted by MVP importance)

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 1 | No timeout/try-catch on secure storage reads at startup | `FakeAuthRepository.restoreSession()`, `SplashScreen._restoreSession()` | **BLOCKER** |
| 2 | INTERNET permission missing in AndroidManifest.xml | `android/app/src/main/AndroidManifest.xml` | **HIGH** |
| 3 | `minSdk = flutter.minSdkVersion` (defaults to 21) — flutter_secure_storage needs >= 23 | `android/app/build.gradle.kts` | **HIGH** |
| 4 | `ApiAuthRepository` — all methods return `Err('API not implemented')` | `auth/data/api_auth_repository.dart` | STUB |
| 5 | No camera/gallery permissions in AndroidManifest | AndroidManifest.xml | MEDIUM |
| 6 | `_addFakePhoto()` in NewReportScreen uses fake paths, no image_picker | `reports/presentation/screens/new_report_screen.dart` | MEDIUM |
| 7 | `ProjectCard.onTap` is empty — no project detail navigation | `projects/presentation/screens/project_list_screen.dart:164` | MEDIUM |
| 8 | No `reportDetail` route wired in router | `app/router.dart` | LOW |
| 9 | No dio setup file found (no network client configured) | — | LOW (only for API stage) |
| 10 | Splash screen has no timeout fallback — if restoreSession never resolves, spinner forever | `splash_screen.dart` | **BLOCKER** (part of #1) |

### Stubs and TODOs
- `auth_provider.dart:14` — `authRepositoryProvider` throws `UnimplementedError('Override in DI')` (overridden in app.dart, OK)
- `api_auth_repository.dart:17` — `TODO: Implement with Dio`
- `build.gradle.kts:18` — `TODO: Specify your own unique Application ID`
- `build.gradle.kts:34` — `TODO: Add your own signing config for the release build`

### Screens Status
| Screen | Status |
|--------|--------|
| SplashScreen | Built, hangs (see bug #1) |
| LoginScreen | Built, has demo credentials hint |
| RegisterScreen | Built |
| ProjectListScreen | Built, onTap stub |
| TeamListScreen | Built |
| ReportListScreen | Built |
| NewReportScreen | Built, fake photos only |
| ProfileScreen | Built |

---

## Stage 1 — Fix Infinite Loading
- [ ] Wrap `restoreSession()` in try/catch + timeout (5s)
- [ ] Add INTERNET permission to AndroidManifest.xml
- [ ] Set minSdk = 23 in build.gradle.kts
- [ ] Add camera/gallery permissions in AndroidManifest.xml
- [ ] Add safety timeout on SplashScreen (fallback to login after 8s)
- [ ] Run `flutter analyze` — no errors
- [ ] Commit

## Stage 2 — Demo Mode
- [ ] Not started

## Stage 3 — Complete Main Scenario
- [ ] Not started

## Stage 4 — Real API
- [ ] Not started
