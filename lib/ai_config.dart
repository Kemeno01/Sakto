const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const geminiModel = 'gemini-3.5-flash-lite';

bool get aiReady => geminiApiKey.trim().isNotEmpty;
