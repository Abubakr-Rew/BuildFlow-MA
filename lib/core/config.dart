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
