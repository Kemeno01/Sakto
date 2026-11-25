part of 'main.dart';

// ============================================================
// 14. PROFILE DRAWER (opens from the circle on Home)
// ============================================================
const kRed = Color(0xFFD50000);

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Drawer(
        backgroundColor: kBg,
        width: math.min(mq.size.width * 0.86, 360),
        child: ListenableBuilder(
            listenable: app,
            builder: (c, _) {
              final people = app.allPeople, google = app.authMode == 'google';
              Widget section(String t, {Widget? trailing}) => Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 8, 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(t.toUpperCase(), style: ts(11, w: w7, c: kMut))),
                    ?trailing,
                  ]));
              Widget stat(String v, String t) => Expanded(
                  child: Container(
                      margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(color: kW18, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [Text(v, style: ts(16, w: w7, c: Colors.white)), Text(t, style: ts(10, c: Colors.white70))])));
              return Column(children: [
                // ---- header: picture, name (tap to edit), account type, quick stats ----
                Container(
                    width: double.infinity, color: kPr,
                    padding: EdgeInsets.fromLTRB(18, mq.padding.top + 18, 10, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        InkWell(onTap: () => editNameDialog(c), customBorder: const CircleBorder(), child: userAvatar(60)),
                        IconButton(onPressed: () => Navigator.pop(c), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                      ]),
                      gap(10),
                      InkWell(
                          onTap: () => editNameDialog(c), borderRadius: BorderRadius.circular(8),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(children: [
                                Flexible(child: Text(app.userName ?? '', overflow: TextOverflow.ellipsis, style: ts(20, w: w7, c: Colors.white))),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_rounded, size: 15, color: Colors.white70),
                              ]))),
                      Row(children: [
                        Icon(google ? Icons.verified_user_rounded : Icons.phone_android_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 4),
                        Flexible(child: Text(google ? (app.userEmail ?? 'Google account') : 'Offline account · this phone only', overflow: TextOverflow.ellipsis, style: ts(11, c: Colors.white70))),
                      ]),
                      gap(14),
                      Row(children: [stat('${app.buckets.length}', 'Tags'), stat('${people.length}', 'People'), stat('${app.hist.length}', 'Saved days')]),
                    ])),
                Expanded(
                    child: ListView(padding: EdgeInsets.zero, children: [
                      // ---- tags ----
                      section('Your tags', trailing: TextButton(onPressed: () { Navigator.pop(c); showSheet(shellCtx ?? c, const TagsSheet()); }, child: Text('Manage', style: ts(12, w: w6, c: kPr)))),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: app.buckets.isEmpty
                              ? Text('No tags yet. Tap Manage to create one.', style: ts(11, c: kMut))
                              : Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final b in app.buckets)
                              InkWell(
                                  onTap: () { Navigator.pop(c); app.ui(() { app.sel = {b}; app.tab = 1; }); },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: TagChip(b))),
                          ])),
                      // ---- people from the Split tab ----
                      section('People you split with'),
                      if (people.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text('No people yet. Add friends inside a tag on the Split tab.', style: ts(11, c: kMut)))
                      else
                        for (final p in people)
                          ListTile(
                              dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                              leading: dotAv(p, 36),
                              title: Text(p, style: ts(14, w: w6)),
                              subtitle: Text(app.tagsOf(p).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, c: kMut)),
                              trailing: Icon(Icons.chevron_right_rounded, color: kMut),
                              onTap: () {
                                final t = app.tagsOf(p);
                                Navigator.pop(c);
                                if (t.isNotEmpty) app.ui(() { app.tab = 2; app.splitTag = t.first; });
                              }),
                      // ---- settings ----
                      section('Settings'),
                      ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                          leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kSel, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.settings_rounded, color: kPr, size: 20)),
                          title: Text('Settings', style: ts(14, w: w6)),
                          subtitle: Text('Theme: ${isDark ? 'Dark' : 'Light'} · data · account', style: ts(11, c: kMut)),
                          trailing: Icon(Icons.chevron_right_rounded, color: kMut),
                          onTap: () { Navigator.pop(c); navKey.currentState?.push(MaterialPageRoute(builder: (_) => const SettingsPage())); }),
                      gap(10),
                    ])),
                // ---- erase current list & sign out ----
                Padding(
                    padding: EdgeInsets.fromLTRB(18, 8, 18, 16 + mq.padding.bottom),
                    child: Column(children: [
                      SizedBox(
                          width: double.infinity, height: 46,
                          child: OutlinedButton.icon(
                              onPressed: () => clearListDialog(c),
                              icon: const Icon(Icons.delete_sweep_rounded, color: kWr, size: 20),
                              label: Text('Erase current list', style: ts(14, w: w6, c: kWr)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: kWr), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                      gap(10),
                      SizedBox(
                          width: double.infinity, height: 48,
                          child: OutlinedButton.icon(
                              onPressed: () => signOutDialog(c),
                              icon: const Icon(Icons.logout_rounded, color: kRed, size: 20),
                              label: Text('Sign out', style: ts(14, w: w6, c: kRed)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                    ])),
              ]);
            }));
  }
}

void editNameDialog(BuildContext c) {
  final t = TextEditingController(text: app.userName);
  void save(BuildContext d) {
    final n = t.text.trim();
    if (n.isEmpty) { toast('Name can’t be empty'); return; }
    app.rename(n);
    syncProfile();
    Navigator.pop(d);
    toast('Name updated');
  }
  showDialog(
      context: c,
      builder: (d) => AlertDialog(
          title: const Text('Edit name'),
          content: TextField(controller: t, autofocus: true, maxLength: 24, textCapitalization: TextCapitalization.words, style: ts(15), decoration: deco('Your name'), onSubmitted: (_) => save(d)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: ts(14, c: kMut))),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kPr), onPressed: () => save(d), child: const Text('Save')),
          ]));
}

void clearListDialog(BuildContext c) => showDialog(
    context: c,
    builder: (d) => AlertDialog(
        title: const Text('Erase current list?'),
        content: const Text('This clears your active items, tags, and split people. Anything saved in your calendar days stays safe so you can review or reuse it anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: ts(14, c: kMut))),
          TextButton(onPressed: () { app.clearActiveList(); Navigator.pop(d); Navigator.pop(c); toast('Current list erased'); }, child: Text('Erase', style: ts(14, c: kWr))),
        ]));

void signOutDialog(BuildContext c) => showDialog(
    context: c,
    builder: (d) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(app.authMode == 'google'
            ? 'You’ll be signed out of Google on this phone. Your lists stay on this phone unless you erase them.'
            : 'Your lists stay on this phone unless you erase them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: ts(14, c: kMut))),
          TextButton(onPressed: () { Navigator.pop(d); signOut(erase: true); }, child: Text('Sign out & erase', style: ts(14, c: kRed))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kPr), onPressed: () { Navigator.pop(d); signOut(); }, child: const Text('Sign out')),
        ]));

// ============================================================
// 15. SETTINGS (theme, account, data)
// ============================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        Widget head(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: Text(t.toUpperCase(), style: ts(11, w: w7, c: kMut)));
        Widget themeOpt(bool d) {
          final on = app.dark == d;
          final bg = d ? const Color(0xFF110F18) : const Color(0xFFF6F5F9), card = d ? const Color(0xFF1C1927) : Colors.white, ln = d ? const Color(0xFF2B2738) : const Color(0xFFEEECF3);
          return Expanded(
              child: InkWell(
                  onTap: () => app.setDark(d), borderRadius: BorderRadius.circular(16),
                  child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: on ? kSel : kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: on ? kPr : kLn, width: on ? 2 : 1)),
                      child: Column(children: [
                        // tiny preview of the theme
                        Container(
                            height: 70, padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: ln)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(height: 14, decoration: BoxDecoration(color: kPr, borderRadius: BorderRadius.circular(4))),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(child: Container(height: 30, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(6)))),
                                const SizedBox(width: 6),
                                Expanded(child: Container(height: 30, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(6)))),
                              ]),
                            ])),
                        gap(8),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(d ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 16, color: on ? kPr : kMut),
                          const SizedBox(width: 6),
                          Text(d ? 'Dark' : 'Light', style: ts(13, w: w7, c: on ? kPr : kInk)),
                        ]),
                      ]))));
        }
        Widget row(IconData i, String t, String v, {VoidCallback? onTap}) => InkWell(
            onTap: onTap, borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Icon(i, size: 20, color: kPr), const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: ts(11, c: kMut)), Text(v, style: ts(14, w: w6), overflow: TextOverflow.ellipsis)])),
                  if (onTap != null) Icon(Icons.edit_rounded, size: 16, color: kMut),
                ])));
        final google = app.authMode == 'google';
        return Scaffold(
            backgroundColor: kBg,
            body: SafeArea(
                child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                  titleRow('Settings', () => Navigator.pop(c)),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        head('Appearance'),
                        Row(children: [themeOpt(false), const SizedBox(width: 10), themeOpt(true)]),
                        head('Account'),
                        cardBox(Column(children: [
                          row(Icons.person_rounded, 'Name', app.userName ?? '', onTap: () => editNameDialog(c)),
                          Divider(height: 1, color: kLn),
                          row(google ? Icons.verified_user_rounded : Icons.phone_android_rounded, 'Signed in with', google ? 'Google · ${app.userEmail ?? ''}' : 'Offline (name only)'),
                        ]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
                        head('Data'),
                        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Your items, tags, splits and history are saved on this phone only.', style: ts(12, c: kMut)),
                          gap(12),
                          bigBtn('Reset all data', () async {
                            final ok = await showDialog<bool>(
                                context: c,
                                builder: (d) => AlertDialog(
                                    title: const Text('Reset everything?'),
                                    content: const Text('This erases all items, tags, history and splits. Your name and theme stay.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Cancel', style: ts(14, c: kMut))),
                                      TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Erase', style: ts(14, c: kRed))),
                                    ]));
                            if (ok == true) { app.resetAll(); toast('All data erased'); }
                          }, bg: kRed),
                        ])),
                        head('About'),
                        cardBox(Row(children: [
                          Icon(Icons.account_balance_wallet_rounded, color: kPr), const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sakto · Spent-To-Sawa', style: ts(14, w: w7)), Text('Version 1.0.0', style: ts(11, c: kMut))])),
                        ])),
                        gap(18),
                        SizedBox(
                            width: double.infinity, height: 48,
                            child: OutlinedButton.icon(
                                onPressed: () => signOutDialog(c),
                                icon: const Icon(Icons.logout_rounded, color: kRed, size: 20),
                                label: Text('Sign out', style: ts(14, w: w6, c: kRed)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                      ])),
                ])));
      });
}
