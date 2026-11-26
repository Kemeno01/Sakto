part of 'main.dart';

bool _sbOk = false;
SupabaseClient? get sb => _sbOk ? Supabase.instance.client : null;

Future<void> initAuth() async {
  if (!supabaseReady) return;
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
    _sbOk = true;

    sb!.auth.onAuthStateChange.listen((data) {
      final u = data.session?.user;
      if (u == null) return;
      if (data.event == AuthChangeEvent.signedIn || (data.event == AuthChangeEvent.initialSession && !app.signedIn)) _onGoogleUser(u);
    });
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }
}

Future<void> _onGoogleUser(User u) async {
  final m = u.userMetadata ?? {};
  final googleName = (m['full_name'] ?? m['name'] ?? u.email?.split('@').first ?? 'Friend').toString();

  final keep = app.authMode == 'google' && app.userEmail == u.email && app.userName != null;
  final wasIn = app.signedIn && app.authMode == 'google';
  await app.setProfile(
      id: 'google_${u.id}',
      name: keep ? app.userName! : googleName,
      email: u.email,
      avatar: (m['avatar_url'] ?? m['picture']) as String?,
      mode: 'google');
  syncProfile();
  if (!wasIn) toast('Signed in as ${app.userName}');
}

Future<void> syncProfile() async {
  final c = sb, u = c?.auth.currentUser;
  if (c == null || u == null || app.authMode != 'google') return;
  try {
    await c.from('profiles').upsert({
      'id': u.id, 'full_name': app.userName, 'email': u.email, 'avatar_url': app.avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (e) {
    debugPrint('Profile sync failed: $e');
  }
}

Future<void> syncCloudData(Map<String, dynamic> data) async {
  final c = sb, u = c?.auth.currentUser;
  if (c == null || u == null || app.authMode != 'google') return;
  try {
    await c.from('user_data').upsert({
      'id': u.id,
      'data': data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (e) {
    debugPrint('Cloud data sync failed: $e');
  }
}

Future<Map<String, dynamic>?> fetchCloudData() async {
  final c = sb, u = c?.auth.currentUser;
  if (c == null || u == null) return null;
  try {
    final row = await c.from('user_data').select('data').eq('id', u.id).maybeSingle();
    final d = row?['data'];
    return d is Map<String, dynamic> ? d : null;
  } catch (e) {
    debugPrint('Cloud data fetch failed: $e');
    return null;
  }
}

Future<void> signInWithGoogle() async {
  final c = sb;
  if (c == null) {
    toast('Google sign-in is not configured yet.');
    return;
  }
  try {
    await c.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : authRedirect,
      queryParams: const {'prompt': 'select_account'},
    );
  } catch (e) {
    debugPrint('Google sign-in failed: $e');
    toast('Google sign-in failed. Check your connection.');
  }
}

Future<void> signOut({bool erase = false}) async {
  try { await sb?.auth.signOut(); } catch (_) {}
  navKey.currentState?.popUntil((r) => r.isFirst);
  await app.clearProfile(erase: erase);
}

Widget userAvatar(double z) {
  final n = (app.userName ?? '').trim(), url = app.avatarUrl;
  final ini = Text(n.isEmpty ? '?' : n[0].toUpperCase(), style: ts(z * 0.4, w: w7, c: kPr));
  return Container(
      width: z, height: z, alignment: Alignment.center, clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: url == null ? ini : Image.network(url, width: z, height: z, fit: BoxFit.cover, errorBuilder: (_, _, _) => ini));
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,

      builder: (_, _) => KeyedSubtree(key: ValueKey('${app.dark}-${app.signedIn}'), child: app.signedIn ? const Shell() : const LandingPage()));
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingState();
}

class _LandingState extends State<LandingPage> {
  final nameC = TextEditingController();
  bool busy = false;

  Future<void> goOffline() async {
    final n = nameC.text.trim();
    if (n.isEmpty) { toast('Type your name first'); return; }
    FocusScope.of(context).unfocus();
    await app.setProfile(id: 'local_${n.toLowerCase()}', name: n, mode: 'local');
  }

  Future<void> goGoogle() async {
    setState(() => busy = true);
    await signInWithGoogle();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
        backgroundColor: kPr,
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: mq.size.height - mq.padding.vertical - 48),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Center(
                          child: Column(children: [
                            Image.asset('assets/icon/sakto_logo_transparent.png', width: 155, height: 155, fit: BoxFit.contain),
                            gap(16),
                            Text('Sakto', style: ts(38, w: w7, c: Colors.white)),
                          ])),
                      gap(40),
                      Text('What should we call you?', style: ts(13, w: w6, c: Colors.white)),
                      gap(8),
                      TextField(
                          controller: nameC, maxLength: 24, textCapitalization: TextCapitalization.words,
                          cursorColor: Colors.white, style: ts(15, w: w6, c: Colors.white),
                          decoration: InputDecoration(
                              hintText: 'e.g. Juan', hintStyle: ts(15, c: Colors.white60),
                              filled: true, fillColor: kW18, counterText: '',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white70, width: 1.5))),
                          onSubmitted: (_) => goOffline()),
                      gap(14),
                      SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                              onPressed: goOffline,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white, foregroundColor: kPr, elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: Text('Continue offline', style: ts(15, w: w7, c: kPr)))),
                      gap(20),
                      Row(children: [
                        const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('or', style: ts(12, c: Colors.white70))),
                        const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                      ]),
                      gap(20),
                      SizedBox(
                          width: double.infinity, height: 50,
                          child: OutlinedButton(
                              onPressed: busy ? null : goGoogle,
                              style: OutlinedButton.styleFrom(
                                  backgroundColor: kW18,
                                  side: const BorderSide(color: Colors.white38, width: 1.2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: busy
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Container(
                                    width: 24, height: 24, alignment: Alignment.center,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: Text('G', style: ts(14, w: FontWeight.w800, c: const Color(0xFF4285F4)))),
                                const SizedBox(width: 10),
                                Text('Continue with Google', style: ts(15, w: w6, c: Colors.white)),
                              ]))),
                      gap(14),
                      Center(child: Text('Google sign-in syncs your account online across devices.', textAlign: TextAlign.center, style: ts(11, c: Colors.white70))),
                    ])))));
  }
}
