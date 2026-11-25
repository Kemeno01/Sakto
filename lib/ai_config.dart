// ============================================================
// GEMINI AI SETTINGS (used for "Scan receipt")
// ============================================================
// 1. Go to https://aistudio.google.com/apikey
// 2. Click "Create API key" (free, no credit card needed)
// 3. Paste your key below (starts with 'AIza...').
//
// TIP: If your GitHub repo is public, avoid pushing your real key
// (or add lib/ai_config.dart to .gitignore after setting it up).

const geminiApiKey = 'AQ.Ab8RN6KF53SQ52f17A-J9y7c8NAIRBR6QuGRRUKtOZv1Jv0t3w'; // e.g. 'AIzaSy...'
const geminiModel = 'gemini-3.5-flash-lite';

bool get aiReady => geminiApiKey.trim().isNotEmpty;
