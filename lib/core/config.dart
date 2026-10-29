/// App-wide configuration flags.
///
/// Set [kUseMockData] to `true` to use in-memory fake repositories
/// instead of real API calls. This allows full app preview without a backend.
const bool kUseMockData = true;

/// Base URL for the real API (only used when [kUseMockData] is false).
/// NOTE: Do NOT use localhost/127.0.0.1 — it doesn't work on real devices.
/// Use the machine's LAN IP or a deployed URL.
const String kApiBaseUrl = 'https://api.buildflow.kg';

/// Demo chats: in a direct chat the other person reads your message after
/// 1–2 s and answers after 2–4 s, so the chat looks alive on one phone.
/// Used only by the fake chat store, i.e. with [kUseMockData].
const bool kFakeChatEcho = true;

/// Share of demo chat messages that fail to send (0–1), to try the
/// «Повторить / Удалить» flow on a device. Used only with [kUseMockData].
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
