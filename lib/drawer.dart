part of 'main.dart';

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

                Container(
                    width: double.infinity, color: kPr,
                    padding: EdgeInsets.fromLTRB(18, mq.padding.top + 18, 10, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        InkWell(onTap: () { Navigator.pop(c); showSheet(shellCtx ?? c, const FriendProfileSheet('Me')); }, customBorder: const CircleBorder(), child: userAvatar(60)),
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
                        Flexible(child: Text(google ? (app.userEmail ?? 'Google') : 'Offline', overflow: TextOverflow.ellipsis, style: ts(11, c: Colors.white70))),
                      ]),
                      gap(14),
                      Row(children: [stat('${app.buckets.length}', 'Tags'), stat('${people.length}', 'People'), stat('${app.hist.length}', 'Saved days')]),
                    ])),
                Expanded(
                    child: ListView(padding: EdgeInsets.zero, children: [

                      section('Your tags', trailing: TextButton(onPressed: () { Navigator.pop(c); showSheet(shellCtx ?? c, const TagsSheet()); }, child: Text('Manage', style: ts(12, w: w6, c: kPr)))),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: app.buckets.isEmpty
                              ? Text('No tags yet', style: ts(11, c: kMut))
                              : Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final b in app.buckets)
                              InkWell(
                                  onTap: () { Navigator.pop(c); app.ui(() { app.sel = {b}; app.tab = 1; }); },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: TagChip(b))),
                          ])),

                      section('People you split with', trailing: TextButton(onPressed: () { Navigator.pop(c); addFriendDialog(shellCtx ?? c); }, child: Text('+ Add', style: ts(12, w: w6, c: kPr)))),
                      if (people.isEmpty)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text('No friends yet', style: ts(11, c: kMut)))
                      else
                        for (final p in people)
                          Builder(builder: (_) {
                            final tags = app.tagsOf(p);
                            return ListTile(
                                dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                                leading: dotAv(p, 38),
                                title: Text(p, style: ts(14, w: w6)),
                                subtitle: tags.isEmpty ? null : Text(tags.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, c: kMut)),
                                trailing: Icon(Icons.photo_camera_outlined, size: 18, color: kMut),
                                onTap: () {
                                  Navigator.pop(c);
                                  showSheet(shellCtx ?? c, FriendProfileSheet(p));
                                });
                          }),

                      section('Recurring bills'),
                      ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                          leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kSel, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.event_repeat_rounded, color: kPr, size: 20)),
                          title: Text('Monthly bills', style: ts(14, w: w6)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (app.dueBills.isNotEmpty)
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: kWr, borderRadius: BorderRadius.circular(10)),
                                  child: Text('${app.dueBills.length} due', style: ts(10, w: w7, c: Colors.white))),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: kMut),
                          ]),
                          onTap: () { Navigator.pop(c); showSheet(shellCtx ?? c, const BillsSheet()); }),

                      if (!google) ...[
                        section('Cloud Sync'),
                        ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kSel, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.cloud_upload_rounded, color: kPr, size: 20)),
                            title: Text('Connect Google & Sync', style: ts(14, w: w6)),
                            trailing: Icon(Icons.chevron_right_rounded, color: kMut),
                            onTap: () { Navigator.pop(c); signInWithGoogle(); }),
                      ],

                      section('Settings'),
                      ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                          leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: kSel, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.settings_rounded, color: kPr, size: 20)),
                          title: Text('Settings', style: ts(14, w: w6)),
                          trailing: Icon(Icons.chevron_right_rounded, color: kMut),
                          onTap: () { Navigator.pop(c); navKey.currentState?.push(MaterialPageRoute(builder: (_) => const SettingsPage())); }),
                      gap(10),
                    ])),

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
        content: const Text('Clears active items and tags. Saved days stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: ts(14, c: kMut))),
          TextButton(onPressed: () { app.clearActiveList(); Navigator.pop(d); Navigator.pop(c); toast('Current list erased'); }, child: Text('Erase', style: ts(14, c: kWr))),
        ]));

void signOutDialog(BuildContext c) => showDialog(
    context: c,
    builder: (d) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Sign out on this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: ts(14, c: kMut))),
          TextButton(onPressed: () { Navigator.pop(d); signOut(erase: true); }, child: Text('Sign out & erase', style: ts(14, c: kRed))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: kPr), onPressed: () { Navigator.pop(d); signOut(); }, child: const Text('Sign out')),
        ]));

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
                          row(google ? Icons.verified_user_rounded : Icons.phone_android_rounded, 'Account', google ? (app.userEmail ?? 'Google') : 'Offline'),
                          if (!google) ...[
                            Divider(height: 1, color: kLn),
                            Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: bigBtn('Connect Google', () => signInWithGoogle())),
                          ],
                        ]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
                        head('Payment details'),
                        cardBox(
                            row(
                                Icons.account_balance_wallet_outlined,
                                'GCash / Maya',
                                app.hasPaymentDetails
                                    ? [
                                        if (app.gcashNumber.isNotEmpty) 'GCash ${app.gcashNumber}',
                                        if (app.mayaNumber.isNotEmpty) 'Maya ${app.mayaNumber}',
                                      ].join(' · ')
                                    : 'Not set',
                                onTap: () => showSheet(c, const PaymentDetailsSheet())),
                            p: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
                        head('Data & Backup'),
                        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (google) ...[
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLn)),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Row(children: [
                                    Icon(
                                        app.pendingCloudSync
                                            ? Icons.cloud_off_rounded
                                            : (app.syncStatus == 'syncing' ? Icons.sync_rounded : Icons.cloud_done_rounded),
                                        size: 16,
                                        color: app.pendingCloudSync ? kWr : kGreen),
                                    const SizedBox(width: 8),
                                    Text(
                                        app.syncStatus == 'syncing'
                                            ? 'Syncing...'
                                            : (app.pendingCloudSync ? 'Pending sync' : 'Synced'),
                                        style: ts(12, w: w6, c: app.pendingCloudSync ? kWr : kInk)),
                                  ]),
                                  TextButton(
                                      onPressed: app.syncStatus == 'syncing'
                                          ? null
                                          : () async {
                                            final ok = await app.flushCloudSync(force: true);
                                            toast(ok ? 'Synced' : 'Offline — will retry');
                                          },
                                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                      child: Text('Sync now', style: ts(12, w: w6, c: kPrText))),
                                ])),
                            gap(12),
                          ],
                          Row(children: [
                            Expanded(child: bigBtn('Export CSV', () => showSheet(c, const ExportCsvSheet()), white: true)),
                            const SizedBox(width: 8),
                            Expanded(child: bigBtn('Backup / Restore', () => showSheet(c, const BackupRestoreSheet()), white: true)),
                          ]),
                          gap(10),
                          bigBtn('Reset all data', () async {
                            final ok = await showDialog<bool>(
                                context: c,
                                builder: (d) => AlertDialog(
                                    title: const Text('Reset everything?'),
                                    content: const Text('Erases all items, tags, history, and splits.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Cancel', style: ts(14, c: kMut))),
                                      TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Erase', style: ts(14, c: kRed))),
                                    ]));
                            if (ok == true) { app.resetAll(); toast('All data erased'); }
                          }, bg: kRed),
                          if (google) ...[
                            gap(10),
                            SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                          context: c,
                                          builder: (d) => AlertDialog(
                                              title: const Text('Delete account & cloud data?'),
                                              content: const Text('Permanently deletes your cloud and local data.'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(d, false), child: Text('Cancel', style: ts(14, c: kMut))),
                                                TextButton(onPressed: () => Navigator.pop(d, true), child: Text('Delete forever', style: ts(14, w: w7, c: kRed))),
                                              ]));
                                      if (ok == true) await deleteAccountAndSignOut();
                                    },
                                    icon: const Icon(Icons.delete_forever_rounded, color: kRed, size: 19),
                                    label: Text('Delete account & cloud data', style: ts(13, w: w6, c: kRed)),
                                    style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
                          ],
                        ])),
                        head('About'),
                        cardBox(Row(children: [
                          Icon(Icons.account_balance_wallet_rounded, color: kPr), const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Sakto', style: ts(14, w: w7)), Text('Version 1.0.0', style: ts(11, c: kMut))])),
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

void addFriendDialog(BuildContext c) {
  final t = TextEditingController();
  void save(BuildContext d) {
    final n = t.text.trim();
    if (n.isEmpty || n.toLowerCase() == 'me') { toast('Enter a friend’s name'); return; }
    app.addSavedFriend(n);
    Navigator.pop(d);
    toast('Saved $n to your friends list');
  }
  showDialog(
      context: c,
      builder: (d) => AlertDialog(
          title: const Text('Add saved friend'),
          content: TextField(controller: t, autofocus: true, maxLength: 20, textCapitalization: TextCapitalization.words, style: ts(15), decoration: deco('e.g. Carlo'), onSubmitted: (_) => save(d)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text('Cancel', style: ts(14, c: kMut))),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kPr), onPressed: () => save(d), child: const Text('Add')),
          ]));
}

class FriendProfileSheet extends StatefulWidget {
  final String person;
  const FriendProfileSheet(this.person, {super.key});
  @override
  State<FriendProfileSheet> createState() => _FriendProfileState();
}
class _FriendProfileState extends State<FriendProfileSheet> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pickPhoto(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 256, maxHeight: 256, imageQuality: 75);
      if (file != null) {
        final bytes = await file.readAsBytes();
        app.setPersonPhoto(widget.person, bytes);
        toast('Photo updated for ${widget.person}');
      }
    } catch (_) {
      toast('Could not open camera/gallery');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final p = widget.person;
        final hasPhoto = app.personPhotoBytes(p) != null;
        final tags = p == 'Me' ? const <String>[] : app.tagsOf(p);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(p == 'Me' ? 'Your photo' : p, style: ts(20, w: w7)),
            closeBtn(c),
          ]),
          gap(14),
          Center(child: dotAv(p, 88, border: false)),
          gap(16),
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text('Gallery', style: ts(13, w: w6, c: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPr, foregroundColor: Colors.white, elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
            const SizedBox(width: 10),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pickPhoto(ImageSource.camera),
                    icon: Icon(Icons.photo_camera_outlined, size: 18, color: kInk),
                    label: Text('Camera', style: ts(13, w: w6)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: kLn),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          ]),
          if (hasPhoto) ...[
            gap(8),
            bigBtn('Remove photo', () {
              app.clearPersonPhoto(p);
              toast('Photo removed');
            }, white: true),
          ],
          if (tags.isNotEmpty) ...[
            gap(14),
            Text('Active splits', style: ts(11, w: w6, c: kMut)),
            gap(8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in tags)
                InkWell(
                    onTap: () { Navigator.pop(c); app.openSplit(t); },
                    borderRadius: BorderRadius.circular(8),
                    child: TagChip(t)),
            ]),
          ],
          if (p != 'Me' && tags.isEmpty) ...[
            gap(12),
            SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                    onPressed: () {
                      app.rmSavedFriend(p);
                      Navigator.pop(c);
                      toast('Removed $p');
                    },
                    icon: const Icon(Icons.person_remove_outlined, size: 18, color: kWr),
                    label: Text('Remove friend', style: ts(13, w: w6, c: kWr)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kWr),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))))),
          ],
        ]);
      });
}

class PaymentDetailsSheet extends StatefulWidget {
  const PaymentDetailsSheet({super.key});
  @override
  State<PaymentDetailsSheet> createState() => _PaymentDetailsState();
}
class _PaymentDetailsState extends State<PaymentDetailsSheet> {
  late final nameC = TextEditingController(text: app.gcashName.isNotEmpty ? app.gcashName : (app.userName ?? ''));
  late final gcashC = TextEditingController(text: app.gcashNumber);
  late final mayaC = TextEditingController(text: app.mayaNumber);

  @override
  void dispose() {
    nameC.dispose();
    gcashC.dispose();
    mayaC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Payment details', style: ts(20, w: w7)),
      closeBtn(context),
    ]),
    label('Account Name'),
    TextField(controller: nameC, maxLength: 32, textCapitalization: TextCapitalization.words, decoration: deco('e.g. Juan D.')),
    label('GCash Number'),
    TextField(controller: gcashC, maxLength: 20, keyboardType: TextInputType.phone, decoration: deco('09XX XXX XXXX')),
    label('Maya Number (optional)'),
    TextField(controller: mayaC, maxLength: 20, keyboardType: TextInputType.phone, decoration: deco('09XX XXX XXXX')),
    gap(14),
    bigBtn('Save payment details', () {
      app.savePaymentDetails(gcashName: nameC.text, gcashNumber: gcashC.text, mayaNumber: mayaC.text);
      Navigator.pop(context);
      toast('Payment details saved');
    }),
  ]);
}

class ExportCsvSheet extends StatelessWidget {
  const ExportCsvSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final csv = app.exportCsv();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Export CSV', style: ts(20, w: w7)),
        closeBtn(context),
      ]),
      gap(10),
      Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLn)),
          child: SingleChildScrollView(child: SelectableText(csv, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')))),
      gap(14),
      bigBtn('Copy CSV to clipboard', () {
        Clipboard.setData(ClipboardData(text: csv));
        Navigator.pop(context);
        toast('CSV copied to clipboard');
      }),
    ]);
  }
}

class BackupRestoreSheet extends StatefulWidget {
  const BackupRestoreSheet({super.key});
  @override
  State<BackupRestoreSheet> createState() => _BackupRestoreState();
}
class _BackupRestoreState extends State<BackupRestoreSheet> {
  final restoreC = TextEditingController();
  @override
  void dispose() { restoreC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Backup & Restore', style: ts(20, w: w7)),
      closeBtn(context),
    ]),
    Text('${app.buckets.length} tags · ${app.hist.length} saved days · ${app.allPeople.length} friends · ${app.inc.length} income entries', style: ts(11, c: kMut)),
    gap(12),
    bigBtn('Copy full JSON backup', () {
      Clipboard.setData(ClipboardData(text: app.exportBackupJson()));
      toast('JSON backup copied! Save it somewhere safe');
    }),
    gap(16),
    label('Restore from JSON backup'),
    TextField(controller: restoreC, maxLines: 4, style: ts(12), decoration: deco('Paste a Sakto JSON backup here...')),
    gap(10),
    bigBtn('Restore backup', () async {
      if (restoreC.text.trim().isEmpty) { toast('Paste a JSON backup first'); return; }
      final err = app.importBackupJson(restoreC.text);
      if (err != null) { toast(err); return; }
      Navigator.pop(context);
      toast('Backup restored!');
    }, white: true),
  ]);
}

class BillsSheet extends StatelessWidget {
  const BillsSheet({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final ym = app.currentYm;
        final list = List.of(app.bills)..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Monthly bills', style: ts(20, w: w7)),
            closeBtn(c),
          ]),
          gap(10),
          if (list.isEmpty)
            cardBox(Text('No recurring bills yet', style: ts(12, c: kMut)), color: kBg)
          else
            for (final b in list)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: cardBox(
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.name, style: ts(14, w: w7)),
                          Text('Day ${b.dayOfMonth} · #${b.bucket}${b.isPaidFor(ym) ? ' · Paid ✓' : ''}', style: ts(11, c: b.isPaidFor(ym) ? kGreen : kMut)),
                        ])),
                        Text(fmt(b.amt), style: ts(14, w: w7)),
                        const SizedBox(width: 6),
                        if (!b.isPaidFor(ym))
                          OutlinedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                app.logBillForCurrentMonth(b);
                                toast('Logged "${b.name}"');
                              },
                              style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  side: BorderSide(color: kPr),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              child: Text('Log', style: ts(11, w: w6, c: kPrText))),
                        PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 18, color: kMut),
                            onSelected: (v) {
                              if (v == 'edit') {
                                billDialog(c, existing: b);
                              } else if (v == 'toggle') {
                                app.toggleBillPaid(b);
                              } else if (v == 'del') {
                                final idx = app.bills.indexOf(b);
                                app.deleteBill(b);
                                toast('Deleted "${b.name}"', actionLabel: 'Undo', onAction: () => app.restoreBill(b, idx));
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('✎  Edit')),
                              PopupMenuItem(value: 'toggle', child: Text(b.isPaidFor(ym) ? '↺  Mark unpaid' : '✓  Mark paid')),
                              const PopupMenuItem(value: 'del', child: Text('🗑  Delete', style: TextStyle(color: kWr))),
                            ]),
                      ]),
                      color: kBg,
                      p: const EdgeInsets.fromLTRB(12, 8, 4, 8))),
          gap(12),
          bigBtn('+ Add monthly bill', () => billDialog(c)),
        ]);
      });
}

void billDialog(BuildContext c, {RecurringBill? existing}) {
  final nameC = TextEditingController(text: existing?.name ?? '');
  final amtC = TextEditingController(text: existing != null ? numStr(existing.amt) : '');
  final dayC = TextEditingController(text: '${existing?.dayOfMonth ?? app.now.day}');
  final tagChoices = <String>{...app.buckets, ...app.tagTemplates}.toList();
  String tag = existing?.bucket ?? (tagChoices.contains('Bills') ? 'Bills' : (tagChoices.isNotEmpty ? tagChoices.first : 'Bills'));
  showDialog(
      context: c,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
              backgroundColor: kCard,
              title: Text(existing == null ? 'Add monthly bill' : 'Edit monthly bill'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: nameC, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Name (e.g. Wi-Fi, Rent)')),
                TextField(controller: amtC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₱)')),
                TextField(controller: dayC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Due day of month (1–31)')),
                gap(12),
                Text('Tag', style: ts(11, w: w6, c: kMut)),
                gap(6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final b in tagChoices)
                    ChoiceChip(
                        label: Text(b, style: ts(11, w: w6, c: tag == b ? Colors.white : kInk)),
                        selected: tag == b,
                        selectedColor: kPr,
                        backgroundColor: kBg,
                        onSelected: (_) => setD(() => tag = b)),
                ]),
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPr),
                    onPressed: () {
                      final n = nameC.text.trim();
                      final a = double.tryParse(amtC.text);
                      final d = int.tryParse(dayC.text) ?? 1;
                      if (n.isEmpty || a == null || a <= 0) { toast('Enter a valid name and amount'); return; }
                      if (existing != null) {
                        app.editBill(existing, n, a, tag, d);
                        toast('Bill updated');
                      } else {
                        app.addBill(n, a, tag, d);
                        toast('Bill added');
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save')),
              ])));
}
