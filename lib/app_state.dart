part of 'main.dart';

class AppState extends ChangeNotifier {
  DateTime get now => DateTime.now();
  String get today => dkey(now);
  late String activeDay = today;
  double cash = 0; int nid = 1, tn = 0;
  List<Item> items = []; List<String> buckets = []; Map<String, int> tc = {};
  Map<String, double> bcash = {};
  Map<String, SplitCfg> sp = {}; List<Income> inc = []; Map<String, HistDay> hist = {};
  List<RecurringBill> bills = []; int nbid = 1;

  int tab = 0; Set<String> sel = {}; String? splitTag; String an = 'Expenses'; bool cmp = true; String? lastAdded;
  int? savedListIndex; String? savedListDay;
  List<String> savedFriends = [];
  Map<String, String> personPhotos = {};
  final Map<String, Uint8List> _photoCache = {};
  List<String> tagTemplates = List.of(kDefaultTemplates);
  String gcashName = '', gcashNumber = '', mayaNumber = '';
  String listQuery = '', listSort = 'default';
  late Rng rng = presetRange('month');

  static const _pkey = 'sakto-profile-v1';
  String? accountId, userName, userEmail, avatarUrl; String authMode = 'local'; bool dark = false;
  String? lastModifiedIso, lastSyncIso;
  bool pendingCloudSync = false;
  String syncStatus = 'idle'; // idle | syncing | synced | offline
  Timer? _syncTimer;
  bool _dirtyInc = true, _dirtyPhotos = true, _dirtyHist = true;
  bool get signedIn => userName != null;

  Future<void> saveProfile() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_pkey,
          jsonEncode({
            'id': accountId, 'name': userName, 'email': userEmail, 'avatar': avatarUrl,
            'mode': authMode, 'dark': dark,
            'gcashName': gcashName, 'gcashNumber': gcashNumber, 'mayaNumber': mayaNumber,
          }));
    } catch (_) {}
  }
  void _prof(VoidCallback f) { f(); saveProfile(); notifyListeners(); }
  void _clearActive() {
    cash = 0; nid = 1; tn = 0; items = []; buckets = []; tc = {}; bcash = {}; sp = {};
    sel = {}; splitTag = null; savedListIndex = null; savedListDay = null;
    listQuery = ''; listSort = 'default';
  }
  void _clearMemory() {
    _clearActive();
    inc = []; hist = {}; bills = []; nbid = 1; savedFriends = []; personPhotos = {}; _photoCache.clear(); tagTemplates = List.of(kDefaultTemplates);
    gcashName = ''; gcashNumber = ''; mayaNumber = '';
    lastModifiedIso = null; lastSyncIso = null; pendingCloudSync = false; syncStatus = 'idle';
    _dirtyInc = true; _dirtyPhotos = true; _dirtyHist = true;
    tab = 0; activeDay = today; rng = presetRange('month');
  }
  void clearActiveList() => mut(_clearActive);
  Future<void> setProfile({required String id, required String name, String? email, String? avatar, String mode = 'local'}) async {
    accountId = id; userName = name; userEmail = email; avatarUrl = avatar; authMode = mode;
    await saveProfile();
    await loadAccountData();
  }
  void rename(String n) => _prof(() => userName = n);
  void setDark(bool v) => _prof(() => dark = v);
  Future<void> clearProfile({bool erase = false}) async {
    _syncTimer?.cancel();
    _syncTimer = null;
    final id = accountId;
    if (erase && id != null) {
      await LocalStore.eraseAccount(id);
    }
    _clearMemory();
    accountId = null; userName = null; userEmail = null; avatarUrl = null; authMode = 'local';
    await saveProfile();
    notifyListeners();
  }

  List<String> get allPeople {
    final s = <String>{...savedFriends};
    for (final b in buckets) { for (final p in sp[b]?.people ?? const <String>[]) { if (p != 'Me') s.add(p); } }
    return s.toList();
  }
  List<String> tagsOf(String p) => buckets.where((b) => sp[b]?.people.contains(p) ?? false).toList();
  void addSavedFriend(String raw) {
    final n = raw.trim();
    if (n.isEmpty || n == 'Me' || savedFriends.contains(n)) return;
    mut(() => savedFriends.add(n));
  }
  void rmSavedFriend(String n) => mut(() {
    savedFriends.remove(n);
    if (tagsOf(n).isEmpty) { personPhotos.remove(n); _photoCache.remove(n); _dirtyPhotos = true; }
  });
  Uint8List? personPhotoBytes(String p) {
    final cached = _photoCache[p];
    if (cached != null) return cached;
    final b64 = personPhotos[p];
    if (b64 == null || b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      _photoCache[p] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }
  void setPersonPhoto(String p, Uint8List bytes) => mut(() {
    personPhotos[p] = base64Encode(bytes);
    _photoCache[p] = bytes;
    _dirtyPhotos = true;
  });
  void clearPersonPhoto(String p) => mut(() {
    personPhotos.remove(p);
    _photoCache.remove(p);
    _dirtyPhotos = true;
  });
  String? addTagTemplate(String raw) {
    final n = raw.trim();
    if (n.isEmpty) return 'Type a template name';
    if (tagTemplates.contains(n)) return 'Template already exists';
    mut(() => tagTemplates.add(n));
    return null;
  }
  void rmTagTemplate(String n) => mut(() => tagTemplates.remove(n));
  void savePaymentDetails({required String gcashName, required String gcashNumber, required String mayaNumber}) {
    this.gcashName = gcashName.trim();
    this.gcashNumber = gcashNumber.trim();
    this.mayaNumber = mayaNumber.trim();
    saveProfile();
    save();
    notifyListeners();
  }
  bool get hasPaymentDetails => gcashNumber.isNotEmpty || mayaNumber.isNotEmpty;
  bool get hasData => items.isNotEmpty || buckets.isNotEmpty || hist.isNotEmpty || inc.isNotEmpty || bills.isNotEmpty || savedFriends.isNotEmpty || cash > 0;

  Map<String, dynamic> toJson() => {
    'updatedAt': lastModifiedIso,
    'activeDay': activeDay, 'cash': cash, 'nid': nid, 'tn': tn, 'nbid': nbid, 'buckets': buckets, 'tc': tc, 'bcash': bcash,
    'savedListIndex': savedListIndex, 'savedListDay': savedListDay,
    'savedFriends': savedFriends, 'personPhotos': personPhotos, 'tagTemplates': tagTemplates,
    'gcashName': gcashName, 'gcashNumber': gcashNumber, 'mayaNumber': mayaNumber,
    'items': items.map((e) => e.toJson()).toList(),
    'sp': sp.map((k, v) => MapEntry(k, v.toJson())),
    'inc': inc.map((e) => e.toJson()).toList(),
    'bills': bills.map((e) => e.toJson()).toList(),
    'hist': hist.map((k, v) => MapEntry(k, v.toJson())),
  };
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pr = prefs.getString(_pkey);
      if (pr != null) {
        final m = jsonDecode(pr) as Map<String, dynamic>;
        accountId = m['id'] as String?;
        userName = m['name'] as String?; userEmail = m['email'] as String?; avatarUrl = m['avatar'] as String?;
        authMode = (m['mode'] as String?) ?? 'local'; dark = m['dark'] == true;
        gcashName = (m['gcashName'] as String?) ?? '';
        gcashNumber = (m['gcashNumber'] as String?) ?? '';
        mayaNumber = (m['mayaNumber'] as String?) ?? '';
        if (accountId == null && userName != null && authMode == 'local') {
          accountId = 'local_${userName!.trim().toLowerCase()}';
        }
      }
      await loadAccountData();
    } catch (_) {}
  }
  void _applyJson(Map<String, dynamic> j) {
    lastModifiedIso = j['updatedAt'] as String?;
    activeDay = (j['activeDay'] as String?) ?? today;
    cash = (j['cash'] as num?)?.toDouble() ?? 0;
    nid = (j['nid'] as int?) ?? 1;
    tn = (j['tn'] as int?) ?? 0;
    buckets = ((j['buckets'] as List?) ?? []).cast<String>();
    tc = ((j['tc'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as int));
    bcash = (j['bcash'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ?? {};
    savedListIndex = j['savedListIndex'] as int?;
    savedListDay = j['savedListDay'] as String?;
    savedFriends = ((j['savedFriends'] as List?) ?? []).cast<String>();
    personPhotos = (j['personPhotos'] as Map?)?.map((k, v) => MapEntry(k as String, v as String)) ?? {};
    _photoCache.clear();
    final tmpl = (j['tagTemplates'] as List?)?.cast<String>();
    tagTemplates = tmpl != null ? List.of(tmpl) : List.of(kDefaultTemplates);
    if (j['gcashName'] is String) gcashName = j['gcashName'] as String;
    if (j['gcashNumber'] is String) gcashNumber = j['gcashNumber'] as String;
    if (j['mayaNumber'] is String) mayaNumber = j['mayaNumber'] as String;
    items = ((j['items'] as List?) ?? []).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
    sp = ((j['sp'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, SplitCfg.fromJson(v as Map<String, dynamic>)));
    inc = ((j['inc'] as List?) ?? []).map((e) => Income.fromJson(e as List)).toList();
    bills = ((j['bills'] as List?) ?? []).map((e) => RecurringBill.fromJson(e as Map<String, dynamic>)).toList();
    nbid = (j['nbid'] as int?) ?? (bills.isEmpty ? 1 : bills.map((b) => b.id).reduce(math.max) + 1);
    hist = ((j['hist'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, HistDay.fromJson(v as Map<String, dynamic>)));
    for (final cfg in sp.values) {
      for (final p in cfg.people) { if (p != 'Me' && !savedFriends.contains(p)) savedFriends.add(p); }
    }
  }

  /// Merges offline/local data non-destructively into the currently loaded account.
  /// Returns true if any data was imported.
  Future<bool> mergeDataMap(Map<String, dynamic> src) async {
    final tmp = AppState().._applyJson(src);
    if (!tmp.hasData) return false;
    if (!hasData) {
      _applyJson(src);
      await save();
      notifyListeners();
      return true;
    }
    var changed = false;
    if (cash == 0 && tmp.cash > 0) { cash = tmp.cash; changed = true; }
    for (final f in tmp.savedFriends) {
      if (!savedFriends.contains(f)) { savedFriends.add(f); changed = true; }
    }
    tmp.personPhotos.forEach((p, b64) {
      if (!personPhotos.containsKey(p) && b64.isNotEmpty) {
        personPhotos[p] = b64;
        _photoCache.remove(p);
        changed = true;
      }
    });
    for (final t in tmp.tagTemplates) {
      if (!tagTemplates.contains(t)) { tagTemplates.add(t); changed = true; }
    }
    if (gcashNumber.isEmpty && tmp.gcashNumber.isNotEmpty) {
      gcashNumber = tmp.gcashNumber;
      if (gcashName.isEmpty) gcashName = tmp.gcashName;
      changed = true;
    }
    if (mayaNumber.isEmpty && tmp.mayaNumber.isNotEmpty) { mayaNumber = tmp.mayaNumber; changed = true; }
    for (final b in tmp.buckets) {
      if (!buckets.contains(b)) {
        buckets.add(b);
        tc[b] = tmp.tc[b] ?? tn++;
        if (tmp.bcash.containsKey(b)) bcash[b] = tmp.bcash[b]!;
        if (tmp.sp.containsKey(b)) sp[b] = tmp.sp[b]!;
        changed = true;
      }
    }
    if (items.isEmpty && tmp.items.isNotEmpty) {
      for (final i in tmp.items) {
        items.add(Item(nid++, i.name, i.price, i.bucket, qty: i.qty, checked: i.checked, who: i.who == null ? null : List.of(i.who!)));
      }
      changed = true;
    }
    tmp.hist.forEach((k, h) {
      if (!hist.containsKey(k)) {
        hist[k] = h;
        changed = true;
      }
    });
    for (final x in tmp.inc) {
      final exists = inc.any((e) => e.d == x.d && (e.a - x.a).abs() < 0.01 && e.cat == x.cat && e.note == x.note);
      if (!exists) { inc.add(x); changed = true; }
    }
    for (final b in tmp.bills) {
      final exists = bills.any((e) => e.name.toLowerCase() == b.name.toLowerCase() && (e.amt - b.amt).abs() < 0.01);
      if (!exists) {
        bills.add(RecurringBill(nbid++, b.name, b.amt, b.bucket, dayOfMonth: b.dayOfMonth, lastPaidMonth: b.lastPaidMonth));
        changed = true;
      }
    }
    if (changed) {
      await save(allPartitions: true);
      notifyListeners();
    }
    return changed;
  }

  /// Resolves local vs cloud state using `updatedAt` timestamps and the offline pending flag.
  /// Returns `'local'`, `'cloud'`, `'merged'`, or `'none'`.
  Future<String> resolveCloudSnapshot(CloudSnapshot? cloud) async {
    final id = accountId;
    if (id == null) return 'none';
    if (cloud == null || cloud.data.isEmpty) {
      if (pendingCloudSync && hasData) {
        _scheduleCloudSync(immediate: true);
        return 'local';
      }
      return 'none';
    }
    final localTs = DateTime.tryParse(lastModifiedIso ?? '');
    final cloudTs = cloud.updatedAt ?? DateTime.tryParse((cloud.data['updatedAt'] as String?) ?? '');
    if (pendingCloudSync && hasData) {
      if (cloudTs != null && (localTs == null || cloudTs.isAfter(localTs))) {
        await mergeDataMap(cloud.data);
        return 'merged';
      }
      _scheduleCloudSync(immediate: true);
      return 'local';
    }
    if (localTs != null && cloudTs != null && localTs.isAfter(cloudTs)) {
      _scheduleCloudSync(immediate: true);
      return 'local';
    }
    _applyJson(cloud.data);
    lastModifiedIso ??= cloudTs?.toUtc().toIso8601String();
    await LocalStore.saveAccount(id, toJson(), writeInc: true, writePhotos: true, writeHist: true);
    pendingCloudSync = false;
    await LocalStore.setPendingSync(id, false);
    syncStatus = 'synced';
    lastSyncIso = DateTime.now().toUtc().toIso8601String();
    return 'cloud';
  }

  Future<void> loadAccountData() async {
    _clearMemory();
    final id = accountId;
    if (id == null) { notifyListeners(); return; }
    final local = await LocalStore.loadAccount(id);
    if (local != null) _applyJson(local);
    pendingCloudSync = await LocalStore.isPendingSync(id);
    if (pendingCloudSync) syncStatus = 'offline';
    if (authMode == 'google') {
      final cloud = await fetchCloudData();
      await resolveCloudSnapshot(cloud);
    }
    if (rolloverIfNeeded()) await save(allPartitions: true);
    notifyListeners();
  }
  bool get hasSavedActiveList =>
      savedListDay == today && savedListIndex != null && (hist[today]?.lists.length ?? 0) > savedListIndex!;

  bool isUnsettledSplit(String b) => isSplit(b) && checked.any((i) => i.bucket == b) && !isTagSettled(b);

  List<HRow> _toHRows(Iterable<Item> src) => src
      .map((i) => HRow(i.name + (i.qty > 1 ? ' ×${i.qty}' : ''), i.amt, i.bucket, myAmt(i), sp[i.bucket]?.mode != null))
      .toList();

  void _resetClearedSplitConfigs() {
    for (final b in buckets) {
      final cfg = sp[b];
      if (cfg == null || isUnsettledSplit(b)) continue;
      if (checked.every((i) => i.bucket != b)) {
        cfg.disc = 0;
        cfg.fee = 0;
        cfg.discPct = false;
        cfg.feePct = false;
        cfg.scVatExempt = false;
        cfg.paidBy = 'Me';
        cfg.paid.clear();
        cfg.given.clear();
        cfg.changed.clear();
      }
    }
  }

  bool rolloverIfNeeded() {
    final cur = today;
    if (activeDay == cur) return false;
    final toArchive = checked.where((i) => !isUnsettledSplit(i.bucket)).toList();
    final rows = _toHRows(toArchive);
    final existing = hist[activeDay];
    final hasSlot = savedListDay == activeDay && savedListIndex != null && existing != null && savedListIndex! < existing.lists.length;
    if (rows.isNotEmpty) {
      final h = hist[activeDay] ??= HistDay(cash, []);
      if (hasSlot) {
        h.lists[savedListIndex!] = rows;
      } else {
        h.lists.add(rows);
      }
      h.cap = math.max(h.cap, cash);
    } else if (hasSlot) {
      existing.lists.removeAt(savedListIndex!);
      if (existing.lists.isEmpty) hist.remove(activeDay);
    }
    items.removeWhere((i) => i.checked && !isUnsettledSplit(i.bucket));
    _resetClearedSplitConfigs();
    activeDay = cur;
    savedListIndex = null;
    savedListDay = null;
    return true;
  }
  void checkRollover() { if (signedIn && rolloverIfNeeded()) { _dirtyHist = true; save(allPartitions: true); notifyListeners(); } }

  Future<void> save({bool allPartitions = false}) async {
    final id = accountId;
    if (id == null) return;
    lastModifiedIso = DateTime.now().toUtc().toIso8601String();
    final data = toJson();
    final wInc = allPartitions || _dirtyInc;
    final wPhotos = allPartitions || _dirtyPhotos;
    final wHist = allPartitions || _dirtyHist;
    _dirtyInc = false;
    _dirtyPhotos = false;
    _dirtyHist = false;
    await LocalStore.saveAccount(id, data, writeMeta: true, writeInc: wInc, writePhotos: wPhotos, writeHist: wHist);
    if (authMode == 'google') {
      pendingCloudSync = true;
      await LocalStore.setPendingSync(id, true);
      _scheduleCloudSync();
    }
  }

  void _scheduleCloudSync({bool immediate = false}) {
    _syncTimer?.cancel();
    if (authMode != 'google' || accountId == null) return;
    _syncTimer = Timer(immediate ? Duration.zero : const Duration(milliseconds: 1200), () {
      flushCloudSync();
    });
  }

  Future<bool> flushCloudSync({bool force = false}) async {
    _syncTimer?.cancel();
    _syncTimer = null;
    final id = accountId;
    if (id == null || authMode != 'google') return false;
    if (!force && !pendingCloudSync) return true;
    syncStatus = 'syncing';
    notifyListeners();
    final ts = lastModifiedIso ?? DateTime.now().toUtc().toIso8601String();
    lastModifiedIso = ts;
    final ok = await syncCloudData(toJson(), ts);
    if (ok) {
      pendingCloudSync = false;
      await LocalStore.setPendingSync(id, false);
      syncStatus = 'synced';
      lastSyncIso = DateTime.now().toUtc().toIso8601String();
    } else {
      pendingCloudSync = true;
      await LocalStore.setPendingSync(id, true);
      syncStatus = 'offline';
    }
    notifyListeners();
    return ok;
  }

  Future<void> retryPendingCloudSync() async {
    if (signedIn && authMode == 'google' && pendingCloudSync) {
      await flushCloudSync();
    }
  }

  /// Manual pull-to-refresh sync for Google accounts (pushes pending edits or pulls newer cloud data).
  Future<String> refreshFromCloud() async {
    checkRollover();
    if (authMode != 'google' || accountId == null) return 'local';
    syncStatus = 'syncing';
    notifyListeners();
    if (pendingCloudSync) {
      final pushed = await flushCloudSync(force: true);
      if (!pushed) return 'offline';
    }
    final cloud = await fetchCloudData();
    if (cloud == null) {
      syncStatus = pendingCloudSync ? 'offline' : 'synced';
      notifyListeners();
      return 'synced';
    }
    final outcome = await resolveCloudSnapshot(cloud);
    notifyListeners();
    return outcome;
  }

  void mut(VoidCallback f) { f(); save(); notifyListeners(); }
  void ui(VoidCallback f) { f(); notifyListeners(); }
  void resetAll() { _dirtyInc = true; _dirtyPhotos = true; _dirtyHist = true; mut(_clearMemory); }

  List<Color> col(String b) => kPal[(tc[b] ?? 0) % kPal.length];
  List<Item> get checked => items.where((i) => i.checked).toList();

  double get total => checked.fold(0.0, (a, i) => a + myAmt(i));
  double get left => cash - total;
  int get pct => cash > 0 ? math.min(100, (total / cash * 100).round()) : 0;
  double bt(String b) => checked.where((i) => i.bucket == b).fold(0.0, (a, i) => a + myAmt(i));
  double gross(String b) => checked.where((i) => i.bucket == b).fold(0.0, (a, i) => a + i.amt);
  int bc(String b) => checked.where((i) => i.bucket == b && (!isSplit(b) || owners(i).contains('Me'))).length;
  void go(int t) => ui(() { if (t == 2) splitTag = null; tab = t; });
  void toggleSel(String b) => ui(() { if (!sel.remove(b)) sel.add(b); });
  void clearSel() => ui(() => sel = {});
  void openSplit(String t) => ui(() { tab = 2; splitTag = t; });
  bool isSplit(String b) => sp[b]?.mode != null;
  void saveBucketCash(String b, double v) => mut(() => bcash[b] = v);

  double get selCash => sel.isEmpty ? cash : sel.fold(0.0, (a, b) => a + (bcash[b] ?? 0));

  double selTotal() {
    if (sel.isEmpty) return total;
    final seen = <String, String>{}; double t = 0;
    for (final i in checked) {
      if (!sel.contains(i.bucket)) continue;
      final k = '${i.name.toLowerCase().trim()}|${i.price}|${i.qty}';
      if (seen[k] != null && seen[k] != i.bucket) continue;
      seen[k] ??= i.bucket;
      t += myAmt(i);
    }
    return t;
  }

  void toggle(Item i) => mut(() => i.checked = !i.checked);
  void setAllChecked(Iterable<Item> list, bool v) => mut(() { for (final i in list) { i.checked = v; } });
  void setListQuery(String q) => ui(() => listQuery = q);
  void setListSort(String s) => ui(() => listSort = s);
  void dup(Item i) => mut(() => items.insert(items.indexOf(i) + 1, Item(nid++, i.name, i.price, i.bucket, qty: i.qty, who: i.who == null ? null : List.of(i.who!))));
  void setCat(Item i, String b) => mut(() => i.bucket = b);
  void delItem(Item i) => mut(() => items.remove(i));
  void restoreItem(Item i, int index) => mut(() {
    if (items.contains(i)) return;
    items.insert(index.clamp(0, items.length), i);
  });
  String get currentYm => today.substring(0, 7);
  List<RecurringBill> get dueBills =>
      bills.where((b) => !b.isPaidFor(currentYm)).toList()..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
  void addBill(String name, double amt, String bucket, int dayOfMonth) => mut(() {
    bills.add(RecurringBill(nbid++, name.trim(), amt, bucket.trim(), dayOfMonth: dayOfMonth.clamp(1, 31)));
  });
  void editBill(RecurringBill b, String name, double amt, String bucket, int dayOfMonth) => mut(() {
    b.name = name.trim();
    b.amt = amt;
    b.bucket = bucket.trim();
    b.dayOfMonth = dayOfMonth.clamp(1, 31);
  });
  void deleteBill(RecurringBill b) => mut(() => bills.remove(b));
  void restoreBill(RecurringBill b, int index) => mut(() {
    if (bills.contains(b)) return;
    bills.insert(index.clamp(0, bills.length), b);
  });
  void logBillForCurrentMonth(RecurringBill b, {bool checked = true}) => mut(() {
    if (!buckets.contains(b.bucket)) { buckets.add(b.bucket); tc[b.bucket] = tn++; }
    items.add(Item(nid++, b.name, b.amt, b.bucket, checked: checked));
    b.lastPaidMonth = currentYm;
  });
  void toggleBillPaid(RecurringBill b) => mut(() {
    b.lastPaidMonth = b.isPaidFor(currentYm) ? null : currentYm;
  });
  void saveItem(Item i, String name, double price, int qty) => mut(() { i.name = name; i.price = price; i.qty = qty; });
  void addItem(String name, double price, int qty, String bucket) => mut(() {
    items.add(Item(nid++, name, price, bucket, qty: qty));
    if (tab != 1 && tab != 2) { tab = 1; sel = {}; }
  });
  void addScannedItems(List<(String, double, int)> list, String bucket, {bool checked = true, double discount = 0, double fee = 0}) => mut(() {
    for (final (name, price, qty) in list) {
      items.add(Item(nid++, name, price, bucket, qty: qty, checked: checked));
    }
    if (discount > 0) spOf(bucket).disc += discount;
    if (fee > 0) spOf(bucket).fee += fee;
    tab = 1; sel = {bucket};
  });

  String? saveTag(String raw, String? rn) {
    final v = raw.trim();
    if (v.isEmpty) return 'Type a tag name';
    if (buckets.contains(v) && v != rn) return 'That tag already exists';
    mut(() {
      if (rn != null) {
        buckets[buckets.indexOf(rn)] = v;
        if (v != rn) {
          tc[v] = tc[rn] ?? 0; tc.remove(rn);
          if (bcash.containsKey(rn)) bcash[v] = bcash.remove(rn)!;
          if (sp.containsKey(rn)) sp[v] = sp.remove(rn)!;
          if (splitTag == rn) splitTag = v;
        }
        for (final x in items) { if (x.bucket == rn) x.bucket = v; }
        for (final h in hist.values) { for (final l in h.lists) { for (final x in l) { if (x.bucket == rn) x.bucket = v; } } }
        if (sel.remove(rn)) sel.add(v);
      } else { buckets.add(v); tc[v] = tn++; lastAdded = v; }
    });
    return null;
  }
  void delTag(String b) => mut(() {
    buckets.remove(b); tc.remove(b); sp.remove(b); bcash.remove(b); items.removeWhere((x) => x.bucket == b);
    sel.remove(b);
    if (splitTag == b) splitTag = null;
  });

  void saveCash(double v) => mut(() { if (v > cash) { inc.add(Income(today, v - cash, cat: 'Cash top-up')); _dirtyInc = true; } cash = v; });
  void addIncome(double amt, {String cat = 'Allowance', String note = '', String? date, bool addToCash = true}) => mut(() {
    inc.add(Income(date ?? today, amt, cat: cat, note: note.trim()));
    if (addToCash) cash += amt;
    _dirtyInc = true;
  });
  void editIncome(Income item, double amt, String cat, String note, String date) => mut(() {
    item.a = amt;
    item.cat = cat;
    item.note = note.trim();
    item.d = date;
    _dirtyInc = true;
  });
  void deleteIncome(Income item) => mut(() { inc.remove(item); _dirtyInc = true; });
  List<Income> incEntries(String a, String b) =>
      inc.where((x) => x.d.compareTo(a) >= 0 && x.d.compareTo(b) <= 0).toList()..sort((p, q) => q.d.compareTo(p.d));

  void addHistoryItem(String dayKey, String name, double amt, String bucket, {int listIndex = 0}) => mut(() {
    if (!buckets.contains(bucket)) { buckets.add(bucket); tc[bucket] = tn++; }
    final h = hist[dayKey] ??= HistDay(cash, []);
    if (h.lists.isEmpty) {
      h.lists.add([HRow(name, amt, bucket)]);
    } else {
      final idx = listIndex.clamp(0, h.lists.length - 1);
      h.lists[idx].add(HRow(name, amt, bucket));
    }
    _dirtyHist = true;
  });
  void editHistoryItem(String dayKey, int listIndex, int rowIndex, String name, double amt, String bucket) => mut(() {
    final h = hist[dayKey];
    if (h == null || listIndex < 0 || listIndex >= h.lists.length) return;
    final l = h.lists[listIndex];
    if (rowIndex < 0 || rowIndex >= l.length) return;
    if (!buckets.contains(bucket)) { buckets.add(bucket); tc[bucket] = tn++; }
    final r = l[rowIndex];
    r.name = name;
    r.amt = amt;
    r.bucket = bucket;
    if (r.mine != null) r.mine = amt;
    _dirtyHist = true;
  });
  void deleteHistoryItem(String dayKey, int listIndex, int rowIndex) => mut(() {
    final h = hist[dayKey];
    if (h == null || listIndex < 0 || listIndex >= h.lists.length) return;
    final l = h.lists[listIndex];
    if (rowIndex < 0 || rowIndex >= l.length) return;
    l.removeAt(rowIndex);
    if (l.isEmpty) {
      h.lists.removeAt(listIndex);
      if (dayKey == savedListDay && savedListIndex != null) {
        if (savedListIndex == listIndex) { savedListIndex = null; savedListDay = null; }
        else if (savedListIndex! > listIndex) { savedListIndex = savedListIndex! - 1; }
      }
    }
    if (h.lists.isEmpty) {
      hist.remove(dayKey);
      if (dayKey == savedListDay) { savedListIndex = null; savedListDay = null; }
    }
    _dirtyHist = true;
  });
  void restoreHistoryItem(String dayKey, int listIndex, int rowIndex, HRow row, {double? cap}) => mut(() {
    if (!buckets.contains(row.bucket)) { buckets.add(row.bucket); tc[row.bucket] = tn++; }
    final h = hist[dayKey] ??= HistDay(cap ?? cash, []);
    while (h.lists.length <= listIndex) {
      h.lists.add([]);
    }
    final l = h.lists[listIndex];
    l.insert(rowIndex.clamp(0, l.length), row);
    _dirtyHist = true;
  });
  void deleteHistoryDay(String dayKey) => mut(() {
    hist.remove(dayKey);
    if (dayKey == savedListDay) { savedListIndex = null; savedListDay = null; }
    _dirtyHist = true;
  });
  bool saveDay() {
    final rows = _toHRows(checked);
    if (rows.isEmpty) return false;
    mut(() {
      final h = hist[today] ??= HistDay(cash, []);
      if (hasSavedActiveList) {
        h.lists[savedListIndex!] = rows;
      } else {
        h.lists.add(rows);
        savedListIndex = h.lists.length - 1;
        savedListDay = today;
      }
      h.cap = math.max(h.cap, cash);
      _dirtyHist = true;
    });
    return true;
  }

  /// Archives checked non-unsettled-split items into today's history and clears
  /// them from the active list so the user can start another list for today.
  /// Returns: 0 = nothing checked, 1 = archived & cleared, 2 = only unsettled splits checked (kept active).
  int saveAndStartNewList() {
    if (checked.isEmpty) return 0;
    final toArchive = checked.where((i) => !isUnsettledSplit(i.bucket)).toList();
    if (toArchive.isEmpty) {
      saveDay();
      return 2;
    }
    final rows = _toHRows(toArchive);
    mut(() {
      final h = hist[today] ??= HistDay(cash, []);
      if (hasSavedActiveList) {
        h.lists[savedListIndex!] = rows;
      } else {
        h.lists.add(rows);
      }
      h.cap = math.max(h.cap, cash);
      items.removeWhere((i) => i.checked && !isUnsettledSplit(i.bucket));
      _resetClearedSplitConfigs();
      savedListIndex = null;
      savedListDay = null;
      _dirtyHist = true;
    });
    return 1;
  }
  void reuse(String k) => mut(() {
    for (final x in hist[k]!.rows) {
      if (!buckets.contains(x.bucket)) { buckets.add(x.bucket); tc[x.bucket] = tn++; }
      items.add(Item(nid++, x.name, x.amt, x.bucket));
    }
    sel = {}; tab = 1;
  });

  SplitCfg spOf(String t) => sp[t] ??= SplitCfg();
  void startSplit(String t, String mode) => mut(() { spOf(t).mode = mode; splitTag = t; });
  void backToTags() => ui(() => splitTag = null);
  void setOwner(Item i, List<String>? w) => mut(() => i.who = w);
  void setPaid(String t, String p, int v) => mut(() { final s = spOf(t); s.paid[p] = v; if (v != 1) { s.given.remove(p); s.changed.remove(p); } });
  void setGiven(String t, String p, double v) => mut(() { final s = spOf(t); s.paid[p] = 1; s.given[p] = v; s.changed.remove(p); });
  void setChanged(String t, String p, bool v) => mut(() => spOf(t).changed[p] = v);

  double recvOf(String t, String p, double total) {
    final s = spOf(t), pd = s.paid[p] ?? 0;
    if (pd == 2) return total;
    if (pd != 1) return 0;
    final g = s.given[p] ?? 0;
    return g > 0 ? math.min(g, total) : total;
  }

  double effDisc(SplitCfg s, double base) {
    if (base <= 0) return 0;
    if (s.scVatExempt) return base - (base / 1.12) * 0.80;
    return s.discPct ? base * (s.disc / 100.0) : s.disc;
  }
  double effFee(SplitCfg s, double base) {
    if (base <= 0) return 0;
    return s.feePct ? base * (s.fee / 100.0) : s.fee;
  }

  double tagReceivedRaw(String t) {
    if (!isSplit(t)) return 0;
    final s = spOf(t), per = calcSplit(t).per;
    double sum = 0;
    for (final e in per.entries) {
      final owed = e.value.total, pd = s.paid[e.key] ?? 0;
      if (pd == 2) { sum += owed; }
      else if (pd == 1) {
        final g = (s.given[e.key] ?? 0) > 0 ? s.given[e.key]! : owed;
        sum += s.changed[e.key] == true ? math.min(g, owed) : g;
      }
    }
    return sum;
  }

  bool isTagSettled(String t) {
    if (!isSplit(t)) return false;
    final s = spOf(t), per = calcSplit(t).per;
    final payers = per.entries.where((e) => e.value.total > 0.005).toList();
    if (payers.isEmpty) return false;
    return payers.every((e) {
      final owed = e.value.total, pd = s.paid[e.key] ?? 0;
      if (pd == 2) return true;
      if (pd != 1) return false;
      final g = (s.given[e.key] ?? 0) > 0 ? s.given[e.key]! : owed;
      return g >= owed - 0.005 && (g <= owed + 0.005 || s.changed[e.key] == true);
    });
  }
  void setDisc(String t, double v) => mut(() { final s = spOf(t); s.disc = v; s.scVatExempt = false; });
  void setFee(String t, double v) => mut(() => spOf(t).fee = v);
  void setDiscPct(String t, bool pct) => mut(() { final s = spOf(t); s.discPct = pct; s.scVatExempt = false; });
  void setFeePct(String t, bool pct) => mut(() => spOf(t).feePct = pct);
  void setScVatExempt(String t, bool v) => mut(() {
    final s = spOf(t);
    s.scVatExempt = v;
    if (v) { s.discPct = true; s.disc = 20; }
  });
  void setPaidBy(String t, String p) => mut(() {
    final s = spOf(t);
    if (!s.people.contains(p)) return;
    s.paidBy = p;
  });
  void addPerson(String t, String name) => mut(() {
    final s = spOf(t);
    if (!s.people.contains(name)) s.people.add(name);
    if (name != 'Me' && !savedFriends.contains(name)) savedFriends.add(name);
  });
  void rmPerson(String t, String p) => mut(() {
    final s = spOf(t); s.people.remove(p); s.paid.remove(p); s.given.remove(p); s.changed.remove(p);
    if (s.paidBy == p) s.paidBy = 'Me';
    for (final i in items) {
      if (i.bucket == t && i.who != null) { i.who = i.who!.where((x) => x != p).toList(); if (i.who!.isEmpty) i.who = null; }
    }
  });
  List<String> owners(Item i) {
    final s = spOf(i.bucket);
    if (s.mode == 'equal' || i.who == null) return s.people;
    final w = i.who!.where((p) => s.people.contains(p)).toList();
    return w.isEmpty ? s.people : w;
  }
  SplitResult calcSplit(String t) {
    final s = spOf(t); final per = <String, PerPerson>{}; double base = 0;
    for (final i in checked.where((i) => i.bucket == t)) {
      final P = owners(i);
      for (final p in P) {
        final o = per[p] ??= PerPerson();
        o.sub += i.amt / P.length; base += i.amt / P.length;
        o.lines.add(Line(i.name + (P.length > 1 ? ' (1/${P.length})' : ''), i.amt / P.length));
      }
    }
    final netAdj = effFee(s, base) - effDisc(s, base);
    for (final o in per.values) { o.total = math.max(0.0, o.sub + (base > 0 ? netAdj * o.sub / base : 0)); }
    return SplitResult(per, base);
  }

  double myAmt(Item i) {
    final s = sp[i.bucket];
    final split = s != null && s.mode != null;
    int share = 1;
    if (split) {
      final P = owners(i);
      if (!P.contains('Me')) return 0;
      share = P.length;
    }
    final raw = i.amt / share;
    if (!i.checked || s == null || (!s.scVatExempt && s.fee == 0 && s.disc == 0)) return raw;
    final base = checked.where((x) => x.bucket == i.bucket).fold(0.0, (a, x) => a + x.amt);
    if (base <= 0) return raw;
    final netAdj = effFee(s, base) - effDisc(s, base);
    return math.max(0.0, raw * (1 + netAdj / base));
  }

  String formatSplitSummary(String t, {bool includeItems = true, String? onlyPerson}) {
    final s = spOf(t), r = calcSplit(t), per = r.per, base = r.base;
    final dAmt = effDisc(s, base), fAmt = effFee(s, base), grand = math.max(0.0, base + fAmt - dAmt);
    final buf = StringBuffer();
    buf.writeln('🧾 $t Split Summary');
    buf.writeln('Total Bill: ${fmt(grand)} (Paid by: ${s.paidBy})');
    if (dAmt > 0.005) {
      final tag = s.scVatExempt ? 'SC/PWD 20% VAT-ex' : (s.discPct ? '${numStr(s.disc)}%' : '');
      buf.writeln('Discount${tag.isEmpty ? '' : ' ($tag)'}: −${fmt(dAmt)}');
    }
    if (fAmt > 0.005) {
      final tag = s.feePct ? '${numStr(s.fee)}%' : '';
      buf.writeln('Service / Tax${tag.isEmpty ? '' : ' ($tag)'}: +${fmt(fAmt)}');
    }
    buf.writeln();
    final entries = onlyPerson == null ? per.entries : per.entries.where((e) => e.key == onlyPerson);
    for (final e in entries) {
      final p = e.key, o = e.value;
      final pd = s.paid[p] ?? 0;
      String status;
      if (pd == 2) {
        status = 'Paid (GCash ✓)';
      } else if (pd == 1) {
        final g = s.given[p] ?? o.total;
        final chg = g - o.total;
        if (chg < -0.005) {
          status = 'Cash ${fmt(g)} (short ${fmt(-chg)})';
        } else if (chg > 0.005) {
          status = 'Cash ${fmt(g)} (change ${fmt(chg)}${s.changed[p] == true ? ' ✓' : ''})';
        } else {
          status = 'Paid (Cash ✓)';
        }
      } else {
        status = p == s.paidBy ? 'Unpaid (paid at counter)' : 'To pay ${s.paidBy}';
      }
      final roleTag = (p == s.paidBy && s.people.length > 1) ? ' (Counter)' : '';
      buf.writeln('• $p$roleTag: ${fmt(o.total)} — $status');
      if (includeItems) {
        for (final l in o.lines) {
          buf.writeln('   - ${l.name}: ${fmt(l.amt)}');
        }
      }
    }
    if (s.paidBy == 'Me' && hasPaymentDetails) {
      buf.writeln();
      buf.writeln('Payment Details:');
      if (gcashNumber.isNotEmpty) buf.writeln('GCash: $gcashNumber${gcashName.isNotEmpty ? ' ($gcashName)' : ''}');
      if (mayaNumber.isNotEmpty) buf.writeln('Maya: $mayaNumber${gcashName.isNotEmpty ? ' ($gcashName)' : ''}');
    }
    return buf.toString().trimRight();
  }

  Rng presetRange(String p) {
    final y = now.year, m = now.month;
    final r = {
      'today': [today, today], '7d': [addD(today, -6), today], '30d': [addD(today, -29), today],
      'month': [dkey(DateTime(y, m, 1)), today], 'last': [dkey(DateTime(y, m - 1, 1)), dkey(DateTime(y, m, 0))],
      '3m': [dkey(DateTime(y, m - 2, 1)), today], 'year': ['$y-01-01', today],
    }[p]!;
    return Rng(p, r[0], r[1]);
  }
  void setPreset(String p) => ui(() => rng = presetRange(p));
  void setDates(String? a, String? b) => ui(() {
    if (a != null) rng.from = a;
    if (b != null) rng.to = b;
    rng.preset = 'custom';
    if (rng.from.compareTo(rng.to) > 0) { if (a != null) { rng.to = rng.from; } else { rng.from = rng.to; } }
  });
  void setAn(String v) => ui(() => an = v);
  void setCmp(bool v) => ui(() => cmp = v);

  List<ERow> expRows(String a, String b) {
    final rows = <ERow>[];
    final liveToday = today.compareTo(a) >= 0 && today.compareTo(b) <= 0;
    final liveChecked = liveToday ? checked : const <Item>[];
    final replaceSavedSlot = liveToday && hasSavedActiveList && liveChecked.isNotEmpty;
    hist.forEach((k, h) {
      if (k.compareTo(a) >= 0 && k.compareTo(b) <= 0) {
        for (var idx = 0; idx < h.lists.length; idx++) {
          if (k == today && replaceSavedSlot && idx == savedListIndex) continue;
          for (final x in h.lists[idx]) {
            final isSplit = x.sp || (x.mine != null && (x.mine! - x.amt).abs() > 0.005);
            rows.add(ERow(x.name, x.mine ?? x.amt, x.bucket, k, full: x.amt, split: isSplit));
          }
        }
      }
    });
    if (liveToday && liveChecked.isNotEmpty && (!hasSavedActiveList || replaceSavedSlot)) {
      for (final i in liveChecked) {
        rows.add(ERow(i.name, myAmt(i), i.bucket, today, full: i.amt, split: sp[i.bucket]?.mode != null));
      }
    }
    return _dedupe(rows);
  }

  String _nm(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'\s*×\d+$'), '');

  List<ERow> _dedupe(List<ERow> rows) {
    final drop = <ERow>{};
    for (final s in rows.where((r) => r.split && r.amt > 0)) {
      for (final p in rows) {
        if (p.split || drop.contains(p) || p.date != s.date || p.bucket == s.bucket) continue;
        if (_nm(p.name) == _nm(s.name) && ((p.amt - s.full).abs() < 0.01 || (p.amt - s.amt).abs() < 0.01)) { drop.add(p); break; }
      }
    }
    return rows.where((r) => !drop.contains(r)).toList();
  }
  List<ERow> incRows(String a, String b) =>
      inc.where((x) => x.d.compareTo(a) >= 0 && x.d.compareTo(b) <= 0)
          .map((x) => ERow(x.note.isEmpty ? x.cat : '${x.cat} · ${x.note}', x.a, x.cat, x.d))
          .toList();

  String _csvEsc(String v) => (v.contains(',') || v.contains('"') || v.contains('\n')) ? '"${v.replaceAll('"', '""')}"' : v;
  String exportCsv() {
    final buf = StringBuffer('Date,Type,Tag/Category,Item/Note,Full Amount,My Share,Split\n');
    final allExp = expRows('1970-01-01', '2999-12-31')..sort((a, b) => b.date.compareTo(a.date));
    for (final r in allExp) {
      buf.writeln('${r.date},Expense,${_csvEsc(r.bucket)},${_csvEsc(r.name)},${r.full.toStringAsFixed(2)},${r.amt.toStringAsFixed(2)},${r.split ? 'Yes' : 'No'}');
    }
    final allInc = List.of(inc)..sort((a, b) => b.d.compareTo(a.d));
    for (final x in allInc) {
      buf.writeln('${x.d},Income,${_csvEsc(x.cat)},${_csvEsc(x.note)},${x.a.toStringAsFixed(2)},${x.a.toStringAsFixed(2)},No');
    }
    return buf.toString();
  }

  String exportBackupJson() => const JsonEncoder.withIndent('  ').convert(toJson());
  String? importBackupJson(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map<String, dynamic>) return 'Invalid backup format';
      if (!decoded.containsKey('buckets') && !decoded.containsKey('items') && !decoded.containsKey('hist')) {
        return 'Not a valid Sakto backup';
      }
      mut(() {
        _applyJson(decoded);
        _dirtyInc = true;
        _dirtyPhotos = true;
        _dirtyHist = true;
      });
      saveProfile();
      return null;
    } catch (_) {
      return 'Could not read JSON backup';
    }
  }
  List<Bar> series(String a, String b, List<ERow> rows) {
    final n = spanDays(a, b), step = n <= 31 ? 1 : (n <= 120 ? 7 : 0);
    final out = <List<String>>[];
    if (step > 0) {
      for (var s = a; s.compareTo(b) <= 0; s = addD(s, step)) {
        final e0 = addD(s, step - 1);
        out.add([step == 1 ? '${int.parse(s.substring(8))}' : s.substring(5), s, e0.compareTo(b) < 0 ? e0 : b]);
      }
    } else {
      for (var d = toD(a); dkey(d).compareTo(b) <= 0; d = DateTime(d.year, d.month + 1, 1)) {
        final s = dkey(d), e = dkey(DateTime(d.year, d.month + 1, 0));
        out.add([m3(d), s.compareTo(a) < 0 ? a : s, e.compareTo(b) > 0 ? b : e]);
      }
    }
    return out.map((o) => Bar(o[0], rows.where((r) => r.date.compareTo(o[1]) >= 0 && r.date.compareTo(o[2]) <= 0).fold(0.0, (t, r) => t + r.amt))).toList();
  }
}

final app = AppState();
final navKey = GlobalKey<NavigatorState>();
BuildContext? shellCtx;
