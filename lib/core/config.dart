import 'package:flutter/foundation.dart';

/// App-wide configuration.

// ── Backend ──────────────────────────────────────────────────

/// Where the data lives.
enum Backend {
  /// In-memory fake repositories with demo data: no server needed.
  fake,

  /// The Supabase project at [BackendConfig.supabaseUrl].
  supabase,
}

/// The backend of this build, from `--dart-define`s:
///
/// * `BACKEND` — `fake` or `supabase`. Unset means `fake` in debug, profile
///   and tests; a release build must say it, so a release never falls back
///   to the demo data by accident.
/// * `SUPABASE_URL`, `SUPABASE_ANON_KEY` — required with `supabase`.
///
/// Locally they come from a file kept out of git:
/// `flutter run --dart-define-from-file=env/local.env` (see README).
@immutable
class BackendConfig {
  const BackendConfig({
    required this.backend,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
  });

  /// Reads the `--dart-define`s; throws [BackendConfigError] if the build
  /// can't run with them.
  factory BackendConfig.fromEnvironment() => BackendConfig.parse(
        backend: const String.fromEnvironment('BACKEND'),
        supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
        release: kReleaseMode,
      );

  /// The rules of [BackendConfig.fromEnvironment], testable.
  factory BackendConfig.parse({
    required String backend,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required bool release,
  }) {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    switch (backend.trim()) {
      case '' when release:
        throw const BackendConfigError(
          'A release build needs --dart-define=BACKEND=supabase with '
          'SUPABASE_URL and SUPABASE_ANON_KEY, or BACKEND=fake for a demo '
          'build.',
        );
      case '' || 'fake':
        return const BackendConfig(backend: Backend.fake);
      case 'supabase':
        if (url.isEmpty || key.isEmpty) {
          throw const BackendConfigError(
            'BACKEND=supabase needs --dart-define=SUPABASE_URL and '
            'SUPABASE_ANON_KEY (e.g. --dart-define-from-file=env/local.env).',
          );
        }
        if (Uri.tryParse(url)?.hasScheme != true) {
          throw BackendConfigError('SUPABASE_URL is not a URL: $url');
        }
        return BackendConfig(
          backend: Backend.supabase,
          supabaseUrl: url,
          supabaseAnonKey: key,
        );
      case final other:
        throw BackendConfigError(
          'Unknown BACKEND "$other": use fake or supabase.',
        );
    }
  }

  final Backend backend;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isFake => backend == Backend.fake;
}

/// A build whose `--dart-define`s don't make a working app. `main` shows
/// it on screen instead of starting.
class BackendConfigError implements Exception {
  const BackendConfigError(this.message);

  final String message;

  @override
  String toString() => 'BackendConfigError: $message';
}

/// Lazily read once; `main` reads it first, so a bad build stops there.
final BackendConfig kBackendConfig = BackendConfig.fromEnvironment();

/// The backend the repository providers pick.
Backend get kBackend => kBackendConfig.backend;

/// Demo chats: in a direct chat the other person reads your message after
/// 1–2 s and answers after 2–4 s, so the chat looks alive on one phone.
/// Used only by the fake chat store, i.e. with [Backend.fake].
const bool kFakeChatEcho = true;

/// Share of demo chat messages that fail to send (0–1), to try the
/// «Повторить / Удалить» flow on a device. Used only with [Backend.fake].
const double kFakeChatSendFailureRate = 0;

/// Photos of reports and chat messages are scaled so the long side is at
/// most this many pixels: seams and cracks stay visible on a phone and a
/// laptop screen, and the file stays small for a slow mobile network.
const int kPhotoMaxSide = 1600;

/// The size a compressed photo aims for. The JPEG qualities of
/// [kPhotoQualitySteps] are tried in turn until the photo fits.
const int kPhotoTargetBytes = 450 * 1024;

/// JPEG qualities to try, best first. If even the last one doesn't fit
/// [kPhotoTargetBytes], the photo goes as is: lower qualities blur exactly
/// the thin lines (cracks, joints) a report is about.
const List<int> kPhotoQualitySteps = [82, 74, 66];

/// Voice messages: AAC-LC in M4A, mono. At 32 kbit/s a five-minute note is
/// about 1.2 MB; speech stays clear on a phone speaker.
const int kVoiceBitRate = 32000;
const int kVoiceSampleRate = 22050;

/// Shorter recordings are dropped with «Удерживайте, чтобы записать».
const Duration kVoiceMinDuration = Duration(seconds: 1);

/// At this length the recording stops and waits as a draft; it is never
/// sent on its own (a note held down in a pocket would be).
const Duration kVoiceMaxDuration = Duration(minutes: 5);

/// Values of the waveform sent with a voice message, each 0–100.
const int kVoiceWaveformBars = 40;
