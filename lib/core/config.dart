/// App-wide configuration flags.
///
/// Set [kUseMockData] to `true` to use in-memory fake repositories
/// instead of real API calls. This allows full app preview without a backend.
const bool kUseMockData = true;

/// Base URL for the real API (only used when [kUseMockData] is false).
/// NOTE: Do NOT use localhost/127.0.0.1 — it doesn't work on real devices.
/// Use the machine's LAN IP or a deployed URL.
const String kApiBaseUrl = 'https://api.buildflow.kg';
