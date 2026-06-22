// API keys are injected at build time via --dart-define.
// Never hardcode secrets here. See docs/ENVIRONMENT_SETUP.md.
class AppConfig {
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
}
