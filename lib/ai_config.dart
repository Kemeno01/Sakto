import 'supabase_config.dart';

/// Optional local-dev Gemini key (passed via `--dart-define-from-file=secrets.json`).
/// For production APKs, leave this unset and deploy the `scan-receipt` Supabase Edge Function
/// so no API key is ever bundled inside the client binary.
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const geminiModel = 'gemini-3.5-flash-lite';

/// Set `--dart-define=USE_EDGE_SCANNER=true` on release builds to force server-side OCR
/// via the `scan-receipt` Supabase Edge Function.
const useEdgeScanner = bool.fromEnvironment('USE_EDGE_SCANNER', defaultValue: false);

bool get hasLocalGeminiKey => geminiApiKey.trim().isNotEmpty;
bool get aiReady => useEdgeScanner ? supabaseReady : (hasLocalGeminiKey || supabaseReady);
