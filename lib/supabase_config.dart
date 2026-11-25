// ============================================================
// SUPABASE SETTINGS (used only for "Continue with Google")
// ============================================================
// 1. Open your project at https://supabase.com/dashboard
// 2. Go to Project Settings → API (or "Connect" → Mobile framework)
// 3. Paste the Project URL and the anon / publishable key below.
//
// The anon key is meant to be public (it ships inside every app).
// Your users' data is protected by the Row Level Security rules in
// SUPABASE_SETUP.md. NEVER paste the service_role / secret key here.
//
// While these are empty the app still works: users can continue
// offline with just their name, and the Google button shows a hint.

const supabaseUrl = 'https://lpsbyblsyaigqdgxnhyn.supabase.co'; // e.g. 'https://abcdefghijkl.supabase.co'
const supabaseAnonKey = 'sb_publishable_dzZX-laE891T-FYn0jTtdw_5QG7iUvU'; // e.g. 'eyJhbGciOiJIUzI1NiIs...' or 'sb_publishable_...'

// Where Supabase sends the user back after Google sign-in.
// Must match: AndroidManifest.xml, ios/Runner/Info.plist and
// Supabase → Authentication → URL Configuration → Redirect URLs.
const authRedirect = 'io.sakto.app://login-callback';

bool get supabaseReady => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
