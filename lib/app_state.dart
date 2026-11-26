part of 'main.dart';

class AppState extends ChangeNotifier {
  DateTime get now => DateTime.now();
  String get today => dkey(now);
  late String activeDay = today;
  double cash = 0; int nid = 1, tn = 0;
  List<Item> items = []; List<String> buckets = []; Map<String, int> tc = {};
  Map<String, double> bcash = {};
  Map<String, SplitCfg> sp = {}; List<Income> inc = []; Map<String, HistDay> hist = {};

  int tab = 0; Set<String> sel = {}; String? splitTag; String an = 'Expenses'; bool cmp = true; String? lastAdded;
  late Rng rng = presetRange('month');

  static const _pkey = 'sakto-profile-v1';
  String? accountId, userName, userEmail, avatarUrl; String authMode = 'local'; bool dark = false;
  bool get signedIn => userName != null;
  String? get _dataKey => accountId == null ? null : 'sakto-data-v1-$accountId';

  Future<void> saveProfile() async {
    try {
      await (await SharedPreferences.getInstance()).setString(_pkey,
          jsonEncode({'id': accountId, 'name': userName, 'email': userEmail, 'avatar': avatarUrl, 'mode': authMode, 'dark': dark}));
    } catch (_) {}
  }
  void _prof(VoidCallback f) { f(); saveProfile(); notifyListeners(); }
  void _clearActive() {
    cash = 0; nid = 1; tn = 0; items = []; buckets = []; tc = {}; bcash = {}; sp = {};
    sel = {}; splitTag = null;
  }
  void _clearMemory() {
    _clearActive();
    inc = []; hist = {}; tab = 0; activeDay = today; rng = presetRange('month');
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
    final k = _dataKey;
    if (erase && k != null) {
      try { await (await SharedPreferences.getInstance()).remove(k); } catch (_) {}
    }
    _clearMemory();
    accountId = null; userName = null; userEmail = null; avatarUrl = null; authMode = 'local';
    await saveProfile();
    notifyListeners();
  }

  List<String> get allPeople {
    final s = <String>{};
    for (final b in buckets) { for (final p in sp[b]?.people ?? const <String>[]) { if (p != 'Me') s.add(p); } }
    return s.toList();
  }
  List<String> tagsOf(String p) => buckets.where((b) => sp[b]?.people.contains(p) ?? false).toList();

  Map<String, dynamic> toJson() => {
    'activeDay': activeDay, 'cash': cash, 'nid': nid, 'tn': tn, 'buckets': buckets, 'tc': tc, 'bcash': bcash,
    'items': items.map((e) => e.toJson()).toList(),
    'sp': sp.map((k, v) => MapEntry(k, v.toJson())),
    'inc': inc.map((e) => [e.d, e.a]).toList(),
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
        if (accountId == null && userName != null && authMode == 'local') {
          accountId = 'local_${userName!.trim().toLowerCase()}';
        }
      }
      await loadAccountData();
    } catch (_) {}
  }
  void _applyJson(Map<String, dynamic> j) {
    activeDay = (j['activeDay'] as String?) ?? today;
    cash = (j['cash'] as num?)?.toDouble() ?? 0;
    nid = (j['nid'] as int?) ?? 1;
    tn = (j['tn'] as int?) ?? 0;
    buckets = ((j['buckets'] as List?) ?? []).cast<String>();
    tc = ((j['tc'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, v as int));
    bcash = (j['bcash'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ?? {};
    items = ((j['items'] as List?) ?? []).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
    sp = ((j['sp'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, SplitCfg.fromJson(v as Map<String, dynamic>)));
    inc = ((j['inc'] as List?) ?? []).map((e) => Income((e as List)[0] as String, (e[1] as num).toDouble())).toList();
    hist = ((j['hist'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, HistDay.fromJson(v as Map<String, dynamic>)));
  }

  Future<void> loadAccountData() async {
    _clearMemory();
    final k = _dataKey;
    if (k == null) { notifyListeners(); return; }
    try {
      final raw = (await SharedPreferences.getInstance()).getString(k);
      if (raw != null) _applyJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    if (authMode == 'google') {
      final cloud = await fetchCloudData();
      if (cloud != null && cloud.isNotEmpty) {
        _applyJson(cloud);
        try { await (await SharedPreferences.getInstance()).setString(k, jsonEncode(cloud)); } catch (_) {}
      }
    }
    if (rolloverIfNeeded()) await save();
    notifyListeners();
  }
  bool rolloverIfNeeded() {
    final cur = today;
    if (activeDay == cur) return false;
    final rows = checked.map((i) => HRow(i.name + (i.qty > 1 ? ' ×${i.qty}' : ''), i.amt, i.bucket, myAmt(i), sp[i.bucket]?.mode != null)).toList();
    if (rows.isNotEmpty) {
      final h = hist[activeDay] ??= HistDay(cash, []);
      h.lists = [rows]; h.cap = cash;
    }
    _clearActive();
    activeDay = cur;
    return true;
  }
  void checkRollover() { if (signedIn && rolloverIfNeeded()) { save(); notifyListeners(); } }
  Future<void> save() async {
    final k = _dataKey;
    if (k == null) return;
    final data = toJson();
    try { await (await SharedPreferences.getInstance()).setString(k, jsonEncode(data)); } catch (_) {}
    if (authMode == 'google') syncCloudData(data);
  }
  void mut(VoidCallback f) { f(); save(); notifyListeners(); }
  void ui(VoidCallback f) { f(); notifyListeners(); }
  void resetAll() => mut(_clearMemory);

  List<Color> col(String b) => kPal[(tc[b] ?? 0) % kPal.length];
  List<Item> get checked => items.where((i) => i.checked).toList();

  double get total => checked.fold(0.0, (a, i) => a + myAmt(i));
  double get left => cash - total;
  int get pct => cash > 0 ? math.min(100, (total / cash * 100).round()) : 0;
  double bt(String b) => checked.where((i) => i.bucket == b).fold(0.0, (a, i) => a + myAmt(i));
  double gross(String b) => checked.where((i) => i.bucket == b).fold(0.0, (a, i) => a + i.amt);
  int bc(String b) => checked.where((i) => i.bucket == b && myAmt(i) > 0).length;
  void go(int t) => ui(() { if (t == 2) splitTag = null; tab = t; });
  void toggleSel(String b) => ui(() { if (!sel.remove(b)) sel.add(b); });
  void clearSel() => ui(() => sel = {});
  void openSplit(String t) => ui(() => splitTag = t);
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
  void dup(Item i) => mut(() => items.insert(items.indexOf(i) + 1, Item(nid++, i.name, i.price, i.bucket, qty: i.qty, who: i.who == null ? null : List.of(i.who!))));
  void setCat(Item i, String b) => mut(() => i.bucket = b);
  void delItem(Item i) => mut(() => items.remove(i));
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

  void saveCash(double v) => mut(() { if (v > cash) inc.add(Income(today, v - cash)); cash = v; });
  bool saveDay() {
    final rows = checked.map((i) => HRow(i.name + (i.qty > 1 ? ' ×${i.qty}' : ''), i.amt, i.bucket, myAmt(i), sp[i.bucket]?.mode != null)).toList();
    if (rows.isEmpty) return false;
    mut(() { final h = hist[today] ??= HistDay(cash, []); h.lists = [rows]; h.cap = cash; });
    return true;
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
  void setDisc(String t, double v) => mut(() => spOf(t).disc = v);
  void setFee(String t, double v) => mut(() => spOf(t).fee = v);
  void addPerson(String t, String name) => mut(() { final s = spOf(t); if (!s.people.contains(name)) s.people.add(name); });
  void rmPerson(String t, String p) => mut(() {
    final s = spOf(t); s.people.remove(p); s.paid.remove(p); s.given.remove(p); s.changed.remove(p);
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
    for (final o in per.values) { o.total = o.sub + (base > 0 ? (s.fee - s.disc) * o.sub / base : 0); }
    return SplitResult(per, base);
  }

  double myAmt(Item i) {
    final s = sp[i.bucket];
    if (s == null || s.mode == null) return i.amt;
    final P = owners(i);
    if (!P.contains('Me')) return 0;
    if (!i.checked) return i.amt / P.length;
    final base = checked.where((x) => x.bucket == i.bucket).fold(0.0, (a, x) => a + x.amt);
    return i.amt / P.length * (1 + (base > 0 ? (s.fee - s.disc) / base : 0));
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
    hist.forEach((k, h) {
      if (k.compareTo(a) >= 0 && k.compareTo(b) <= 0) {
        for (final x in h.rows) {
          final isSplit = x.sp || (x.mine != null && (x.mine! - x.amt).abs() > 0.005);
          rows.add(ERow(x.name, x.mine ?? x.amt, x.bucket, k, full: x.amt, split: isSplit));
        }
      }
    });
    if (!hist.containsKey(today) && today.compareTo(a) >= 0 && today.compareTo(b) <= 0) {
      for (final i in checked) { rows.add(ERow(i.name, myAmt(i), i.bucket, today, full: i.amt, split: sp[i.bucket]?.mode != null)); }
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
      inc.where((x) => x.d.compareTo(a) >= 0 && x.d.compareTo(b) <= 0).map((x) => ERow('Cash on hand · ${x.d}', x.a, '', x.d)).toList();
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
