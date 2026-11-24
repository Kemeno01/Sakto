// Spent-To-Sawa: Flutter version
// Needs two packages: flutter pub add shared_preferences google_fonts
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 1. CONSTANTS & HELPERS
// ============================================================
const kInk = Color(0xFF1B1630), kMut = Color(0xFF6B6580), kPr = Color(0xFF7B4DEB);
const kBg = Color(0xFFF6F5F9), kLn = Color(0xFFEEECF3), kLil = Color(0xFF9B6BFF), kWr = Color(0xFFC2410C);
const kW18 = Color(0x2EFFFFFF), kW35 = Color(0x59FFFFFF);
const w6 = FontWeight.w600, w7 = FontWeight.w700;
const kMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const kWd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
// tag colors: [background, text/chart color]
const List<List<Color>> kPal = [
  [Color(0xFFEDE4FF), Color(0xFF5B2FD0)], [Color(0xFFDDF3E6), Color(0xFF14683A)],
  [Color(0xFFFFE6D6), Color(0xFFA04100)], [Color(0xFFDCEBFF), Color(0xFF0B57B5)],
  [Color(0xFFFFF3C9), Color(0xFF7A5A00)], [Color(0xFFFFE0F0), Color(0xFFA0155F)],
  [Color(0xFFE3E8FF), Color(0xFF2F3FA8)], [Color(0xFFD9F5F2), Color(0xFF0B6B63)],
];
// people colors
const List<List<Color>> kPc = [
  [Color(0xFFEDE7FF), Color(0xFF5B2EE0)], [Color(0xFFDCFCE7), Color(0xFF166534)],
  [Color(0xFFFEF3C7), Color(0xFFB45309)], [Color(0xFFDBEAFE), Color(0xFF1D4ED8)],
  [Color(0xFFFCE7F3), Color(0xFFBE185D)], [Color(0xFFCCFBF1), Color(0xFF0F766E)],
];
List<Color> pcOf(String p) => p == 'Me' ? kPc[0] : kPc[1 + p.codeUnits.fold(0, (a, c) => a + c) % 5];

String fmt(double n) {
  final s = n.abs().toStringAsFixed(2).split('.');
  final w = s[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '${n < 0 ? '−' : ''}₱$w.${s[1]}';
}
String numStr(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
String two(int n) => n.toString().padLeft(2, '0');
String dkey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
DateTime toD(String k) => DateTime.parse(k);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
String addD(String k, int n) => dkey(addDays(toD(k), n));
int spanDays(String a, String b) => (toD(b).difference(toD(a)).inHours / 24).round() + 1;
String m3(DateTime d) => kMonths[d.month - 1].substring(0, 3);
String dayLabel(String k) { final d = toD(k); return '${kWd[d.weekday % 7]}, ${m3(d)} ${d.day}'; }
String rangeLabel(String a, String b) => '${m3(toD(a))} ${toD(a).day} – ${m3(toD(b))} ${toD(b).day}, ${toD(b).year}';

// ============================================================
// 2. MODELS
// ============================================================
class Item {
  int id; String name; double price; int qty; String bucket; bool checked; List<String>? who;
  Item(this.id, this.name, this.price, this.bucket, {this.qty = 1, this.checked = false, this.who});
  double get amt => price * qty;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'qty': qty, 'bucket': bucket, 'checked': checked, 'who': who};
  factory Item.fromJson(Map<String, dynamic> j) => Item(j['id'] as int, j['name'] as String, (j['price'] as num).toDouble(), j['bucket'] as String,
      qty: j['qty'] as int, checked: j['checked'] as bool, who: (j['who'] as List?)?.cast<String>());
}

class HRow {
  String name; double amt; String bucket; double? mine; bool sp; // sp = came from a split tag
  HRow(this.name, this.amt, this.bucket, [this.mine, this.sp = false]);
  double get own => mine ?? amt; // your own share (full amount if the tag was never split)
  List<dynamic> toJson() => [name, amt, bucket, mine, sp];
  factory HRow.fromJson(List<dynamic> j) => HRow(j[0] as String, (j[1] as num).toDouble(), j[2] as String,
      j.length > 3 && j[3] != null ? (j[3] as num).toDouble() : null, j.length > 4 && j[4] == true);
}

class HistDay {
  double cap; List<List<HRow>> lists;
  HistDay(this.cap, this.lists);
  List<HRow> get rows => lists.expand((l) => l).toList();
  double get sum => rows.fold(0.0, (a, x) => a + x.own);
  Map<String, dynamic> toJson() => {'cap': cap, 'lists': lists.map((l) => l.map((x) => x.toJson()).toList()).toList()};
  factory HistDay.fromJson(Map<String, dynamic> j) => HistDay((j['cap'] as num).toDouble(),
      (j['lists'] as List).map((l) => (l as List).map((x) => HRow.fromJson(x as List)).toList()).toList());
}

class SplitCfg {
  String? mode; List<String> people; double disc, fee; Map<String, int> paid;
  Map<String, double> given; Map<String, bool> changed; // cash handed to you / change already returned
  SplitCfg({this.mode, List<String>? people, this.disc = 0, this.fee = 0, Map<String, int>? paid, Map<String, double>? given, Map<String, bool>? changed})
      : people = people ?? ['Me'], paid = paid ?? {}, given = given ?? {}, changed = changed ?? {};
  Map<String, dynamic> toJson() => {'mode': mode, 'people': people, 'disc': disc, 'fee': fee, 'paid': paid, 'given': given, 'changed': changed};
  factory SplitCfg.fromJson(Map<String, dynamic> j) => SplitCfg(mode: j['mode'] as String?, people: (j['people'] as List).cast<String>(),
      disc: (j['disc'] as num).toDouble(), fee: (j['fee'] as num).toDouble(), paid: (j['paid'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      given: (j['given'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      changed: (j['changed'] as Map?)?.map((k, v) => MapEntry(k as String, v as bool)));
}

class Income { String d; double a; Income(this.d, this.a); }
class Line { String name; double amt; Line(this.name, this.amt); }
class PerPerson { double sub = 0, total = 0; List<Line> lines = []; }
class SplitResult { Map<String, PerPerson> per; double base; SplitResult(this.per, this.base); }
class ERow {
  String name; double amt; String bucket; String date; double full; bool split;
  ERow(this.name, this.amt, this.bucket, this.date, {double? full, this.split = false}) : full = full ?? amt;
}
class Bar { String label; double v; Bar(this.label, this.v); }
class Group { String name; double v; Color color; Group(this.name, this.v, this.color); }
class Rng { String preset, from, to; Rng(this.preset, this.from, this.to); }

// ============================================================
// 3. APP STATE (saved on the phone)
// ============================================================
class AppState extends ChangeNotifier {
  static const _key = 'spent-to-sawa-flutter-v1';
  final DateTime now = DateTime.now();
  late final String today = dkey(now);
  double cash = 0; int nid = 1, tn = 0;
  List<Item> items = []; List<String> buckets = []; Map<String, int> tc = {};
  Map<String, double> bcash = {}; // cash on hand per tag
  Map<String, SplitCfg> sp = {}; List<Income> inc = []; Map<String, HistDay> hist = {};
  // screen state (not saved)
  int tab = 0; Set<String> sel = {}; String? splitTag; String an = 'Expenses'; bool cmp = true; String? lastAdded;
  late Rng rng = presetRange('month');

  // ---- save / load ----
  Map<String, dynamic> toJson() => {
    'cash': cash, 'nid': nid, 'tn': tn, 'buckets': buckets, 'tc': tc, 'bcash': bcash,
    'items': items.map((e) => e.toJson()).toList(),
    'sp': sp.map((k, v) => MapEntry(k, v.toJson())),
    'inc': inc.map((e) => [e.d, e.a]).toList(),
    'hist': hist.map((k, v) => MapEntry(k, v.toJson())),
  };
  Future<void> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      cash = (j['cash'] as num).toDouble(); nid = j['nid'] as int; tn = j['tn'] as int;
      buckets = (j['buckets'] as List).cast<String>();
      tc = (j['tc'] as Map).map((k, v) => MapEntry(k as String, v as int));
      bcash = (j['bcash'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())) ?? {};
      items = (j['items'] as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
      sp = (j['sp'] as Map).map((k, v) => MapEntry(k as String, SplitCfg.fromJson(v as Map<String, dynamic>)));
      inc = (j['inc'] as List).map((e) => Income((e as List)[0] as String, (e[1] as num).toDouble())).toList();
      hist = (j['hist'] as Map).map((k, v) => MapEntry(k as String, HistDay.fromJson(v as Map<String, dynamic>)));
    } catch (_) {}
  }
  Future<void> save() async {
    try { await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(toJson())); } catch (_) {}
  }
  void mut(VoidCallback f) { f(); save(); notifyListeners(); }
  void ui(VoidCallback f) { f(); notifyListeners(); }
  void resetAll() => mut(() {
    cash = 0; nid = 1; tn = 0; items = []; buckets = []; tc = {}; bcash = {}; sp = {}; inc = []; hist = {};
    tab = 0; sel = {}; splitTag = null; rng = presetRange('month');
  });

  // ---- basics ----
  List<Color> col(String b) => kPal[(tc[b] ?? 0) % kPal.length];
  List<Item> get checked => items.where((i) => i.checked).toList();
  // YOUR own money. Items in a tag shared with others count only your share.
  double get total => checked.fold(0.0, (a, i) => a + myAmt(i));
  double get left => cash - total;
  int get pct => cash > 0 ? math.min(100, (total / cash * 100).round()) : 0;
  double bt(String b) => checked.where((i) => i.bucket == b).fold(0.0, (a, i) => a + myAmt(i)); // your share of the tag
  double gross(String b) => checked.where((i) => i.bucket == b).fold(0.0, (a, i) => a + i.amt); // whole bill (Split tab)
  int bc(String b) => checked.where((i) => i.bucket == b && myAmt(i) > 0).length;
  void go(int t) => ui(() { if (t == 2) splitTag = null; tab = t; });
  void toggleSel(String b) => ui(() { if (!sel.remove(b)) sel.add(b); });
  void clearSel() => ui(() => sel = {});
  void openSplit(String t) => ui(() => splitTag = t);
  bool isSplit(String b) => sp[b]?.mode != null;
  void saveBucketCash(String b, double v) => mut(() => bcash[b] = v);
  // cap for the tags selected in Lists (nothing selected = your overall cash on hand)
  double get selCash => sel.isEmpty ? cash : sel.fold(0.0, (a, b) => a + (bcash[b] ?? 0));
  // Total of the selected tags only. Same name + price in two different selected tags counts once.
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

  // ---- items ----
  void toggle(Item i) => mut(() => i.checked = !i.checked);
  void dup(Item i) => mut(() => items.insert(items.indexOf(i) + 1, Item(nid++, i.name, i.price, i.bucket, qty: i.qty, who: i.who == null ? null : List.of(i.who!))));
  void setCat(Item i, String b) => mut(() => i.bucket = b);
  void delItem(Item i) => mut(() => items.remove(i));
  void saveItem(Item i, String name, double price, int qty) => mut(() { i.name = name; i.price = price; i.qty = qty; });
  void addItem(String name, double price, int qty, String bucket) => mut(() {
    items.add(Item(nid++, name, price, bucket, qty: qty));
    if (tab != 1 && tab != 2) { tab = 1; sel = {}; }
  });

  // ---- tags ----
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

  // ---- cash & history ----
  void saveCash(double v) => mut(() { if (v > cash) inc.add(Income(today, v - cash)); cash = v; });
  bool saveDay() {
    final rows = checked.map((i) => HRow(i.name + (i.qty > 1 ? ' ×${i.qty}' : ''), i.amt, i.bucket, myAmt(i), sp[i.bucket]?.mode != null)).toList();
    if (rows.isEmpty) return false;
    mut(() { final h = hist[today] ??= HistDay(cash, []); h.lists.add(rows); h.cap = cash; });
    return true;
  }
  void reuse(String k) => mut(() {
    for (final x in hist[k]!.rows) {
      if (!buckets.contains(x.bucket)) { buckets.add(x.bucket); tc[x.bucket] = tn++; }
      items.add(Item(nid++, x.name, x.amt, x.bucket));
    }
    sel = {}; tab = 1;
  });

  // ---- splitting (every tag has its own group of people) ----
  SplitCfg spOf(String t) => sp[t] ??= SplitCfg();
  void startSplit(String t, String mode) => mut(() { spOf(t).mode = mode; splitTag = t; });
  void backToTags() => ui(() => splitTag = null);
  void setOwner(Item i, List<String>? w) => mut(() => i.who = w);
  void setPaid(String t, String p, int v) => mut(() { final s = spOf(t); s.paid[p] = v; if (v != 1) { s.given.remove(p); s.changed.remove(p); } });
  void setGiven(String t, String p, double v) => mut(() { final s = spOf(t); s.paid[p] = 1; s.given[p] = v; s.changed.remove(p); });
  void setChanged(String t, String p, bool v) => mut(() => spOf(t).changed[p] = v);
  // how much of what p owes has actually been received (cash with no amount typed = full amount, like before)
  double recvOf(String t, String p, double total) {
    final s = spOf(t), pd = s.paid[p] ?? 0;
    if (pd == 2) return total;
    if (pd != 1) return 0;
    final g = s.given[p] ?? 0;
    return g > 0 ? math.min(g, total) : total;
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
  // My own part of an item (fees/discounts included). Items in a tag you never split count fully as yours.
  double myAmt(Item i) {
    final s = sp[i.bucket];
    if (s == null || s.mode == null) return i.amt;
    final P = owners(i);
    if (!P.contains('Me')) return 0;
    if (!i.checked) return i.amt / P.length; // not counted yet, so no fees/discounts applied
    final base = checked.where((x) => x.bucket == i.bucket).fold(0.0, (a, x) => a + x.amt);
    return i.amt / P.length * (1 + (base > 0 ? (s.fee - s.disc) / base : 0));
  }

  // ---- analytics range ----
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
  // today's active list counts (as my share) until it is saved
  List<ERow> expRows(String a, String b) {
    final rows = <ERow>[];
    hist.forEach((k, h) {
      if (k.compareTo(a) >= 0 && k.compareTo(b) <= 0) {
        for (final x in h.rows) {
          final isSplit = x.sp || (x.mine != null && (x.mine! - x.amt).abs() > 0.005); // also detects old saved data
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

  // If a split item and a normal item are the same thing (same day, name, price), count it once.
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
  List<Bar> series(String a, String b, List<ERow> rows) { // by day (<=31 days), week (<=120), else month
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

void toast(String m) {
  final o = navKey.currentState?.overlay;
  if (o == null) return;
  final e = OverlayEntry(builder: (_) => Positioned(left: 0, right: 0, bottom: 110,
      child: IgnorePointer(child: Center(child: Material(color: kInk, borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12))))))));
  o.insert(e);
  Future.delayed(const Duration(milliseconds: 1900), () => e.remove());
}

// ============================================================
// 4. SMALL REUSABLE WIDGETS
// ============================================================
TextStyle ts(double s, {FontWeight w = FontWeight.w400, Color c = kInk}) => TextStyle(fontSize: s, fontWeight: w, color: c);
Widget gap(double h) => SizedBox(height: h);

Widget cardBox(Widget child, {EdgeInsets p = const EdgeInsets.all(14), EdgeInsets m = EdgeInsets.zero, Color color = Colors.white, double r = 16, Border? border}) =>
    Container(margin: m, padding: p, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(r), border: border), child: child);

Widget progress(int pct, {Color track = kW35, Color fill = Colors.white}) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(height: 6, child: Stack(fit: StackFit.expand, children: [
      ColoredBox(color: track),
      Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: (pct / 100).clamp(0.0, 1.0), child: ColoredBox(color: fill))),
    ])));

Widget bigBtn(String t, VoidCallback f, {bool white = false, Color? bg}) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton(
        onPressed: f,
        style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? (white ? Colors.white : kPr), foregroundColor: white ? kInk : Colors.white, elevation: 0,
            side: white ? const BorderSide(color: kLn) : null, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(t, style: ts(15, w: w6, c: white ? kInk : Colors.white))));

InputDecoration deco(String hint) => InputDecoration(
    hintText: hint, filled: true, fillColor: kLn, counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none));

class TagChip extends StatelessWidget {
  final String b;
  const TagChip(this.b, {super.key});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: app.col(b)[0], borderRadius: BorderRadius.circular(8)),
      child: Text(b, style: ts(10, w: w6, c: app.col(b)[1])));
}

Widget dotAv(String p, double z) {
  final c = pcOf(p);
  return Container(width: z, height: z, alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c[0], border: Border.all(color: Colors.white, width: 2)),
      child: Text(p.isEmpty ? '?' : p[0].toUpperCase(), style: ts(12, w: w7, c: c[1])));
}
Widget avStack(List<String> ps, double z) {
  final l = ps.take(4).toList();
  return SizedBox(width: z + (l.length - 1) * z * 0.7, height: z, child: Stack(children: [for (var k = 0; k < l.length; k++) Positioned(left: k * z * 0.7, child: dotAv(l[k], z))]));
}

class QtyStepper extends StatelessWidget {
  final int q; final ValueChanged<int> onChanged;
  const QtyStepper(this.q, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) {
    Widget b(String t, Color bg, VoidCallback f) => InkWell(onTap: f, borderRadius: BorderRadius.circular(6),
        child: Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)), child: Text(t, style: ts(15, w: w7, c: Colors.white))));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      b('−', const Color(0xFF575757), () => onChanged(math.max(1, q - 1))),
      Container(width: 38, alignment: Alignment.center, child: Text('$q', style: ts(13, w: w6))),
      b('+', kPr, () => onChanged(q + 1)),
    ]);
  }
}

class NumField extends StatefulWidget {
  final double value; final ValueChanged<double> onChanged;
  const NumField({super.key, required this.value, required this.onChanged});
  @override
  State<NumField> createState() => _NumFieldState();
}
class _NumFieldState extends State<NumField> {
  late final c = TextEditingController(text: widget.value == 0 ? '' : numStr(widget.value));
  @override
  Widget build(BuildContext context) => TextField(
      controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(hintText: '0', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      onChanged: (v) => widget.onChanged(math.max(0.0, double.tryParse(v) ?? 0.0)));
}

Future<T?> showSheet<T>(BuildContext c, Widget child) => showModalBottomSheet<T>(
    context: c, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 44, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFD9D5E6), borderRadius: BorderRadius.circular(2)))),
              child,
            ]))));

Widget closeBtn(BuildContext c) => InkWell(onTap: () => Navigator.pop(c), borderRadius: BorderRadius.circular(20),
    child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: const BoxDecoration(color: kLn, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18)));

Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: ts(11, w: w6)));

Widget segBar(List<MapEntry<Color, double>> parts) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(height: 6, child: Row(children: [
      for (final p in parts) Expanded(flex: math.max(1, (p.value * 100).round()), child: Container(margin: const EdgeInsets.only(right: 2), color: p.key)),
    ])));

Widget titleRow(String t, VoidCallback onBack, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(child: InkWell(onTap: onBack, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('← $t', style: ts(20, w: w6), overflow: TextOverflow.ellipsis)))),
      if (trailing != null) trailing,
    ]));

Widget softBtn(String t, VoidCallback f) => OutlinedButton(
    onPressed: f,
    style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kMut, side: const BorderSide(color: kLn), minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    child: Text(t, style: ts(11, w: w6, c: kMut)));

// ============================================================
// 5. APP SHELL (bottom navigation)
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  runApp(const SpentApp());
}

class SpentApp extends StatelessWidget {
  const SpentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Spent-To-Sawa', debugShowCheckedModeBanner: false, navigatorKey: navKey,
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: kPr),
          scaffoldBackgroundColor: kBg,
          textTheme: GoogleFonts.poppinsTextTheme(),
          popupMenuTheme: const PopupMenuThemeData(color: Colors.white)),
      home: const Shell());
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        shellCtx = c;
        const pages = [HomePage(), ListsPage(), SplitPage(), StatsPage()];
        Widget nav(int i, IconData ic, String t) => Expanded(
            child: InkWell(onTap: () => app.go(i),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ic, color: app.tab == i ? kInk : kMut), Text(t, style: ts(10, w: app.tab == i ? w7 : FontWeight.w500, c: app.tab == i ? kInk : kMut)),
                ])));
        return Scaffold(
            body: pages[app.tab],
            floatingActionButton: FloatingActionButton(
                onPressed: () => showSheet(c, const AddItemSheet()),
                backgroundColor: kLil, foregroundColor: Colors.white, shape: const CircleBorder(), child: const Icon(Icons.add, size: 32)),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
                color: Colors.white, shape: const CircularNotchedRectangle(), notchMargin: 8, height: 64, padding: EdgeInsets.zero,
                child: Row(children: [
                  nav(0, Icons.home_rounded, 'Home'), nav(1, Icons.format_list_bulleted_rounded, 'Lists'),
                  const SizedBox(width: 76),
                  nav(2, Icons.donut_large_rounded, 'Split'), nav(3, Icons.bar_chart_rounded, 'Analytics'),
                ])));
      });
}

// ============================================================
// 6. HOME
// ============================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  bool strip = false; // the day strip opens when you tap the date pill

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final left = app.left, warn = app.cash > 0 && left <= app.cash * 0.3, now = app.now;
        final days = [for (var k = -5; k <= 1; k++) addDays(now, k)];
        final latest = app.checked.where((i) => app.myAmt(i) > 0).toList().reversed.take(3).toList();
        return SingleChildScrollView(
            child: Container(color: kPr, child: Column(children: [
              Padding(
                  padding: EdgeInsets.fromLTRB(18, MediaQuery.of(c).padding.top + 14, 18, 0),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      InkWell(onTap: () => showSheet(c, const UserSheet()), customBorder: const CircleBorder(),
                          child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Text('J', style: ts(14, w: w6)))),
                      InkWell(onTap: () => setState(() => strip = !strip), borderRadius: BorderRadius.circular(18),
                          child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 18), alignment: Alignment.center,
                              decoration: BoxDecoration(color: kW18, borderRadius: BorderRadius.circular(18)),
                              child: Text('${m3(now)}. ${two(now.day)}, ${now.year} ${strip ? '▴' : '▾'}', style: ts(12, w: FontWeight.w500, c: Colors.white)))),
                      InkWell(onTap: () => budgetAlert(), customBorder: const CircleBorder(),
                          child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kW18, shape: BoxShape.circle),
                              child: Stack(alignment: Alignment.center, children: [
                                const Icon(Icons.notifications, color: Colors.white, size: 20),
                                if (warn) Positioned(top: 9, right: 10, child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFFF2D2D), shape: BoxShape.circle))),
                              ]))),
                    ]),
                    if (strip) ...[
                      gap(16),
                      Row(children: [
                        for (final d in days)
                          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: InkWell(
                              onTap: () => showSheet(c, CalendarSheet(initial: dkey(d))), borderRadius: BorderRadius.circular(14),
                              child: Container(height: 62, decoration: BoxDecoration(color: dkey(d) == app.today ? Colors.white : kW18, borderRadius: BorderRadius.circular(14)),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text(kWd[d.weekday % 7], style: ts(11, c: dkey(d) == app.today ? const Color(0xFF5B2FD0) : Colors.white)),
                                    Text(two(d.day), style: ts(15, w: w7, c: dkey(d) == app.today ? const Color(0xFF5B2FD0) : Colors.white)),
                                    Icon(Icons.circle, size: 5, color: app.hist.containsKey(dkey(d)) ? (dkey(d) == app.today ? const Color(0xFF5B2FD0) : Colors.white) : Colors.transparent),
                                  ]))))),
                      ]),
                      gap(6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: [const Icon(Icons.circle, size: 5, color: Colors.white), const SizedBox(width: 4), Text('Has a saved list', style: ts(10, c: Colors.white))]),
                        TextButton(onPressed: () => showSheet(c, CalendarSheet(initial: app.today)), child: Text('See all ›', style: ts(10, c: Colors.white))),
                      ]),
                    ],
                    gap(10),
                    Text('Active total · your own money', style: ts(13, c: Colors.white70)),
                    Text(fmt(app.total), style: ts(44, w: w7, c: Colors.white)),
                    gap(6),
                    progress(app.pct),
                    gap(6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${app.pct}% of budget', style: ts(11, c: Colors.white)),
                      InkWell(onTap: () => showSheet(c, const CashSheet()), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Cash on hand ${fmt(app.cash)} ›', style: ts(11, c: Colors.white)))),
                    ]),
                  ])),
              gap(18),
              Container(
                  width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                  decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your Buckets', style: ts(16, w: w6)), gap(10),
                    if (app.buckets.isEmpty)
                      cardBox(Text('No tags yet. Open Lists → Edit Tag to create your first tag.', style: ts(11, c: kMut)))
                    else
                      GridView.count(
                          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0,
                          children: [
                            for (final b in app.buckets)
                              InkWell(onTap: () { app.sel = {b}; app.go(1); }, borderRadius: BorderRadius.circular(16),
                                  child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    TagChip(b), const Spacer(),
                                    Text(fmt(app.bt(b)), style: ts(19, w: w7)),
                                    Text('${app.bc(b)} items${app.isSplit(b) ? ' · shared tag' : ''}', style: ts(10, c: kMut)),
                                    gap(6),
                                    InkWell(onTap: () => showSheet(c, CashSheet(tag: b)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text((app.bcash[b] ?? 0) > 0 ? 'Cash ${fmt(app.bcash[b]!)} ›' : 'Set cash on hand ›', style: ts(10, w: w6, c: kPr)),
                                      if ((app.bcash[b] ?? 0) > 0)
                                        Text('Left ${fmt(app.bcash[b]! - app.bt(b))}', style: ts(10, w: w6, c: app.bcash[b]! - app.bt(b) >= 0 ? const Color(0xFF14683A) : kWr)),
                                    ]))),
                                  ]))),
                          ]),
                    gap(18), Text('Latest items', style: ts(16, w: w6)), gap(8),
                    cardBox(
                        latest.isEmpty
                            ? Text('Nothing checked yet. Tap + to add your first item.', style: ts(11, c: kMut))
                            : Column(children: [
                          for (final i in latest)
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i.name, style: ts(15, w: w7)), Text('${i.bucket} · checked', style: ts(11, c: kMut))])),
                              Text(fmt(app.myAmt(i)), style: ts(14, w: w7)),
                            ])),
                        ]),
                        p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                  ])),
            ])));
      });
}

void budgetAlert() {
  final l = app.left;
  toast(app.cash == 0 ? 'Set your cash on hand first' : (l >= 0 ? '${fmt(l)} left of your ${fmt(app.cash)} cap' : 'Over your cap by ${fmt(-l)}'));
}

class UserSheet extends StatelessWidget {
  const UserSheet({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Spent-To-Sawa', style: ts(18, w: w7)), gap(4),
    Text('Your data is saved on this device only.', style: ts(11, c: kMut)), gap(14),
    bigBtn('Reset all data', () async {
      final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(backgroundColor: Colors.white, title: const Text('Reset everything?'), content: const Text('This erases all items, tags, history and settings.'),
          actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Erase'))]));
      if (ok == true) { app.resetAll(); if (context.mounted) Navigator.pop(context); }
    }, bg: const Color(0xFFD50000)),
  ]);
}

// ============================================================
// 7. CASH ON HAND SHEET (overall, or one tag)
// ============================================================
class CashSheet extends StatefulWidget {
  final String? tag; // null = overall cash on hand
  const CashSheet({super.key, this.tag});
  @override
  State<CashSheet> createState() => _CashState();
}
class _CashState extends State<CashSheet> {
  late final double cur = widget.tag == null ? app.cash : (app.bcash[widget.tag] ?? 0);
  late String raw = cur > 0 ? numStr(cur) : '';
  void key(String k) => setState(() {
    if (k == '⌫') { if (raw.isNotEmpty) raw = raw.substring(0, raw.length - 1); }
    else if (k == '.') { if (!raw.contains('.')) raw += raw.isEmpty ? '0.' : '.'; }
    else {
      if (raw.contains('.') && raw.split('.')[1].length >= 2) return;
      if (raw.length < 9) raw += k;
    }
  });
  @override
  Widget build(BuildContext context) {
    final tg = widget.tag;
    final v = double.tryParse(raw) ?? 0.0, spent = tg == null ? app.total : app.bt(tg), left = v - spent, p = v > 0 ? math.min(100, (spent / v * 100).round()) : 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tg == null ? 'Cash on hand' : 'Cash · $tg', style: ts(20, w: w7)),
          Text(tg == null ? 'How much can you spend on this trip?' : 'How much cash is set aside for this tag?', style: ts(11, c: kMut)),
        ])),
        closeBtn(context),
      ]),
      gap(14),
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: kPr, width: 2), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New amount · was ${fmt(cur)}', style: ts(11, c: kMut)),
            Text('₱${raw.isEmpty ? '0' : raw}', style: ts(34, w: w7)),
          ])),
      gap(12),
      Row(children: [
        for (final n in [100, 500, 1000])
          Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(
              label: Text('+₱$n', style: ts(12, w: w6, c: const Color(0xFF5B2FD0))), backgroundColor: const Color(0xFFEDE4FF), side: BorderSide.none,
              onPressed: () => setState(() => raw = numStr((double.tryParse(raw) ?? 0.0) + n)))),
      ]),
      gap(8),
      cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('After saving', style: ts(11, c: kMut)), Text('${fmt(left)} left', style: ts(11, w: w7, c: left >= 0 ? const Color(0xFF14683A) : const Color(0xFFD50000)))]),
        gap(6), progress(p, track: const Color(0xFFE5DBFF), fill: kPr), gap(6),
        Text('${fmt(spent)} spent · $p% of budget used', style: ts(11, c: kMut)),
      ]), color: kBg, r: 14, p: const EdgeInsets.all(12)),
      gap(8),
      GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.4, children: [
        for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'])
          InkWell(onTap: () => key(k), borderRadius: BorderRadius.circular(14), child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(14)), child: Text(k, style: ts(20, w: w6)))),
      ]),
      gap(14),
      bigBtn('Save cash on hand', () {
        final x = double.tryParse(raw);
        if (x == null || x < 0) { toast('Enter an amount'); return; }
        if (tg == null) { app.saveCash(x); } else { app.saveBucketCash(tg, x); }
        Navigator.pop(context); toast('Cash on hand saved');
      }),
    ]);
  }
}

// ============================================================
// 8. SPENDING HISTORY (calendar) + DAY DETAIL
// ============================================================
class CalendarSheet extends StatefulWidget {
  final String initial;
  const CalendarSheet({super.key, required this.initial});
  @override
  State<CalendarSheet> createState() => _CalState();
}
class _CalState extends State<CalendarSheet> {
  late String cd = widget.initial;
  late DateTime cm = DateTime(toD(widget.initial).year, toD(widget.initial).month, 1);
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final y = cm.year, mo = cm.month, first = DateTime(y, mo, 1).weekday % 7, n = DateTime(y, mo + 1, 0).day, mk = '$y-${two(mo)}';
        final count = app.hist.entries.where((e) => e.key.startsWith(mk)).fold(0, (a, e) => a + e.value.lists.length);
        final H = app.hist[cd];
        final parts = H == null
            ? <MapEntry<Color, double>>[]
            : H.rows.map((r) => r.bucket).toSet().map((b) => MapEntry(app.col(b)[1], H.rows.where((r) => r.bucket == b).fold(0.0, (a, r) => a + r.own))).where((e) => e.value > 0).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Spending history', style: ts(20, w: w7)),
            TextButton(onPressed: () => setState(() { cd = app.today; cm = DateTime(app.now.year, app.now.month, 1); }), child: Text('Today', style: ts(13, w: w6, c: kPr))),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              IconButton(onPressed: () => setState(() => cm = DateTime(y, mo - 1, 1)), icon: const Icon(Icons.chevron_left, color: kPr)),
              Text('${kMonths[mo - 1]} $y', style: ts(14, w: w7)),
              IconButton(onPressed: () => setState(() => cm = DateTime(y, mo + 1, 1)), icon: const Icon(Icons.chevron_right, color: kPr)),
            ]),
            Text('$count saved lists', style: ts(11, c: kMut)),
          ]),
          Row(children: [for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) Expanded(child: Center(child: Text(d, style: ts(11, c: kMut))))]),
          GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.1, children: [
            for (var k = 0; k < first; k++) const SizedBox(),
            for (var d = 1; d <= n; d++)
              Builder(builder: (_) {
                final k = '$mk-${two(d)}', sel = k == cd, saved = app.hist.containsKey(k);
                return InkWell(onTap: () => setState(() => cd = k), borderRadius: BorderRadius.circular(12),
                    child: Container(margin: const EdgeInsets.all(2), alignment: Alignment.center,
                        decoration: BoxDecoration(color: sel ? kPr : null, borderRadius: BorderRadius.circular(12), border: (k == app.today && !sel) ? Border.all(color: kPr, width: 2) : null),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('$d', style: ts(13, w: saved ? w7 : FontWeight.w500, c: sel ? Colors.white : const Color(0xFF3B3650))),
                          if (saved) Icon(Icons.circle, size: 4, color: sel ? Colors.white : kPr),
                        ])));
              }),
          ]),
          gap(6),
          Row(children: [const Icon(Icons.circle, size: 5, color: kPr), const SizedBox(width: 4), Text('Day with a saved list.', style: ts(11, c: kMut))]),
          gap(10),
          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (H != null) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dayLabel(cd), style: ts(15, w: w7)), Text('${H.rows.length} items · ${H.lists.length} list${H.lists.length > 1 ? 's' : ''}', style: ts(11, c: kMut))]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(fmt(H.sum), style: ts(20, w: w7)), Text('of ${fmt(H.cap)}', style: ts(11, c: kMut))]),
              ]),
              gap(8), segBar(parts), gap(8),
              bigBtn('View this list', () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(MaterialPageRoute(builder: (_) => DayPage(cd)));
              }),
            ] else
              Text('No saved list on ${dayLabel(cd)}.', style: ts(11, c: kMut)),
            if (cd == app.today) ...[
              gap(8),
              bigBtn("Save today's list${H != null ? ' as another list' : ''}", () { toast(app.saveDay() ? 'Saved to spending history' : 'Check some items first'); }, white: H != null),
            ],
          ]), color: kBg, r: 18),
        ]);
      });
}

class DayPage extends StatelessWidget {
  final String k;
  const DayPage(this.k, {super.key});
  @override
  Widget build(BuildContext context) {
    final H = app.hist[k];
    if (H == null) return Scaffold(appBar: AppBar(title: const Text('Back')));
    final rows = H.rows, sp = H.sum;
    final parts = rows.map((r) => r.bucket).toSet().map((b) => MapEntry(b, rows.where((r) => r.bucket == b).fold(0.0, (a, r) => a + r.own))).where((e) => e.value > 0).toList();
    return Scaffold(
        body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          titleRow(dayLabel(k), () => Navigator.pop(context)),
          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('You spent', style: ts(11, c: kMut)),
            Text.rich(TextSpan(children: [TextSpan(text: fmt(sp), style: ts(30, w: w7)), TextSpan(text: ' / ${fmt(H.cap)}', style: ts(11, c: kMut))])),
            gap(8), segBar([for (final p in parts) MapEntry(app.col(p.key)[1], p.value)]), gap(8),
            Wrap(spacing: 12, runSpacing: 4, children: [for (final p in parts) Text('● ${p.key} ${fmt(p.value)}', style: ts(11, c: app.col(p.key)[1]))]),
            gap(8),
            Text(H.cap >= sp ? '${fmt(H.cap - sp)} under budget' : '${fmt(sp - H.cap)} over budget', style: ts(11, w: w6, c: H.cap >= sp ? const Color(0xFF14683A) : kWr)),
          ]), m: const EdgeInsets.symmetric(horizontal: 18), r: 18, p: const EdgeInsets.all(16)),
          gap(12),
          cardBox(Column(children: [
            for (final r in rows)
              Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Row(children: [
                Icon(Icons.check_box, color: kPr.withValues(alpha: .6), size: 22), const SizedBox(width: 10),
                Expanded(child: Text(r.name, style: ts(14, w: FontWeight.w500))), TagChip(r.bucket), const SizedBox(width: 8),
                SizedBox(width: 78, child: Text(fmt(r.own), textAlign: TextAlign.right, style: ts(13, w: w7))),
              ])),
          ]), m: const EdgeInsets.symmetric(horizontal: 18), r: 18, p: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
          Padding(padding: const EdgeInsets.all(18), child: Column(children: [
            bigBtn('Reuse for today', () { app.reuse(k); Navigator.popUntil(context, (r) => r.isFirst); toast('Items copied to today’s list'); }),
            gap(8),
            bigBtn('Back to calendar', () {
              Navigator.pop(context);
              final sc = shellCtx;
              if (sc != null && sc.mounted) showSheet(sc, CalendarSheet(initial: k));
            }, white: true),
          ])),
        ])));
  }
}

// ============================================================
// 9. LISTS (items, tags)
// ============================================================
class ListsPage extends StatelessWidget {
  const ListsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final S = app.sel, L = app.items.where((i) => S.isEmpty || S.contains(i.bucket)).toList();
        final t = app.selTotal(), cap = app.selCash, left = cap - t, pct = cap > 0 ? math.min(100, (t / cap * 100).round()) : 0;
        Item? next;
        if (cap > 0) { for (final i in L) { if (!i.checked && app.myAmt(i) > left) { next = i; break; } } }
        Widget chip(String b, bool on, VoidCallback f) => Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: f, borderRadius: BorderRadius.circular(18),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 18), alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? kInk : Colors.white, borderRadius: BorderRadius.circular(18)),
                child: Text(b, style: ts(12, w: FontWeight.w500, c: on ? Colors.white : kInk)))));
        return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
          titleRow('Weekend grocery', () => app.go(0), trailing: softBtn('Edit Tag', () => showSheet(c, const TagsSheet()))),
          SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
            chip('All', S.isEmpty, app.clearSel),
            for (final b in app.buckets) chip(b, S.contains(b), () => app.toggleSel(b)),
          ])),
          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.isEmpty ? 'Your running total · all tags' : 'Your total · ${S.join(' + ')}', style: ts(11, c: kMut)),
            Text.rich(TextSpan(children: [TextSpan(text: fmt(t), style: ts(30, w: w7)), TextSpan(text: ' / ${fmt(cap)}', style: ts(11, c: kMut))])),
            gap(6), progress(pct, track: const Color(0xFFE5DBFF), fill: kPr),
            if (app.buckets.any(app.isSplit)) ...[gap(6), Text('Shared tags count only your share. The whole bill is in the Split tab.', style: ts(10, c: kMut))],
            if (S.isEmpty) ...[gap(6), Text('Tip: tap two or more tags to see only their combined total.', style: ts(10, c: kMut))],
          ]), m: const EdgeInsets.fromLTRB(18, 12, 18, 12), r: 18, p: const EdgeInsets.all(16)),
          if (next != null)
            cardBox(Text('Heads up: adding ${next.name} puts you ${fmt(t + app.myAmt(next) - cap)} over budget.', style: ts(12, c: Colors.white)), color: kWr, r: 14, m: const EdgeInsets.fromLTRB(18, 0, 18, 12), p: const EdgeInsets.all(12)),
          cardBox(
              L.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(app.buckets.isEmpty ? 'Start with Edit Tag: create your tags first, then add items.' : 'No items yet. Tap + to add one.', style: ts(11, c: kMut)))
                  : Column(children: [for (final i in L) ItemRow(i)]),
              m: const EdgeInsets.symmetric(horizontal: 18), r: 18, p: const EdgeInsets.symmetric(horizontal: 14)),
        ]));
      });
}

class ItemRow extends StatelessWidget {
  final Item i;
  const ItemRow(this.i, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        InkWell(onTap: () => app.toggle(i), borderRadius: BorderRadius.circular(7),
            child: Container(width: 24, height: 24, alignment: Alignment.center,
                decoration: BoxDecoration(color: i.checked ? kPr : null, borderRadius: BorderRadius.circular(7), border: Border.all(color: i.checked ? kPr : const Color(0xFF8E8E8E), width: 2)),
                child: i.checked ? const Icon(Icons.check, size: 15, color: Colors.white) : null)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [TextSpan(text: i.name, style: ts(15, w: w7)), if (i.qty > 1) TextSpan(text: '  ×${i.qty}', style: ts(11, c: kMut))])),
          const SizedBox(height: 3), TagChip(i.bucket),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt(app.myAmt(i)), style: ts(15, w: w7)),
          if (app.isSplit(i.bucket) && (app.myAmt(i) - i.amt).abs() > 0.005) Text('of ${fmt(i.amt)} · shared', style: ts(10, c: kMut)),
        ]),
        PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: kInk),
            onSelected: (v) {
              switch (v) {
                case 'edit': editItemDialog(context, i); break;
                case 'dup': app.dup(i); toast('Item duplicated'); break;
                case 'cat': catDialog(context, i); break;
                case 'del': delDialog(context, i); break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('✎  Edit item')),
              PopupMenuItem(value: 'dup', child: Text('⧉  Duplicate')),
              PopupMenuItem(value: 'cat', child: Text('◈  Change Category')),
              PopupMenuItem(value: 'del', child: Text('🗑  Delete Item', style: TextStyle(color: kWr))),
            ]),
      ]));
}

void editItemDialog(BuildContext c, Item i) {
  final nameC = TextEditingController(text: i.name), priceC = TextEditingController(text: numStr(i.price));
  int q = i.qty;
  showDialog(context: c, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      backgroundColor: Colors.white, title: const Text('Edit Item'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: priceC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (₱)')),
        gap(14), Text('Quantity', style: ts(12, w: w6)), gap(6), QtyStepper(q, (v) => set(() => q = v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: kPr), onPressed: () {
          final p = double.tryParse(priceC.text);
          if (nameC.text.trim().isEmpty || p == null || p < 0) { toast('Check the name and price'); return; }
          app.saveItem(i, nameC.text.trim(), p, q); Navigator.pop(ctx);
        }, child: const Text('Save')),
      ])));
}

void catDialog(BuildContext c, Item i) => showDialog(context: c, builder: (ctx) => SimpleDialog(
    backgroundColor: Colors.white, title: const Text('Change Category'),
    children: app.buckets.isEmpty
        ? [const Padding(padding: EdgeInsets.all(20), child: Text('No tags yet. Create one with Edit Tag.'))]
        : [for (final b in app.buckets) SimpleDialogOption(onPressed: () { app.setCat(i, b); Navigator.pop(ctx); }, child: Align(alignment: Alignment.centerLeft, child: TagChip(b)))]));

void delDialog(BuildContext c, Item i) => showDialog(context: c, builder: (ctx) => AlertDialog(
    backgroundColor: Colors.white, title: const Text('Delete Item'), content: Text('Delete "${i.name}"?'),
    actions: [
      TextButton(onPressed: () { app.delItem(i); Navigator.pop(ctx); toast('Item deleted'); }, child: const Text('Yes', style: TextStyle(color: kWr))),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
    ]));

// ---- Add item ----
class AddItemSheet extends StatefulWidget {
  const AddItemSheet({super.key});
  @override
  State<AddItemSheet> createState() => _AddItemState();
}
class _AddItemState extends State<AddItemSheet> {
  final nameC = TextEditingController(), priceC = TextEditingController();
  int qty = 1;
  String? bucket = (app.sel.length == 1 && app.buckets.contains(app.sel.first)) ? app.sel.first : (app.buckets.isEmpty ? null : app.buckets.first);

  @override
  Widget build(BuildContext context) {
    final p = double.tryParse(priceC.text) ?? 0.0;
    final mine = (bucket != null && app.isSplit(bucket!)) ? p * qty / app.spOf(bucket!).people.length : p * qty;
    final t = app.total + mine;
    return ListenableBuilder(listenable: app, builder: (c, _) {
      if (bucket != null && !app.buckets.contains(bucket)) bucket = null;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Add Item', style: ts(20, w: w7)),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: ts(15, w: FontWeight.w500, c: kMut))),
        ]),
        gap(8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Item name', style: ts(11, w: w6)), QtyStepper(qty, (v) => setState(() => qty = v))]),
        gap(6), TextField(controller: nameC, textCapitalization: TextCapitalization.sentences, decoration: deco('e.g. Pancit Canton')),
        label('Price (₱)'),
        TextField(controller: priceC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('0.00'), onChanged: (_) => setState(() {})),
        gap(14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Bucket', style: ts(11, w: w6)),
          TextButton(onPressed: () async {
            await showSheet(context, const TagsSheet());
            if (app.lastAdded != null) { setState(() => bucket = app.lastAdded); app.lastAdded = null; }
          }, child: Text('+ Add Tag', style: ts(11, w: w6, c: kMut))),
        ]),
        if (app.buckets.isEmpty) Text('No tags yet. Tap + Add Tag first.', style: ts(11, c: kMut))
        else Wrap(spacing: 6, runSpacing: 6, children: [
          for (final b in app.buckets)
            InkWell(onTap: () => setState(() => bucket = b), borderRadius: BorderRadius.circular(20),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(color: bucket == b ? const Color(0xFFD0D0D0) : null, borderRadius: BorderRadius.circular(20)),
                    child: Text(b, style: ts(12, w: bucket == b ? w7 : FontWeight.w500)))),
        ]),
        gap(12),
        Text(p <= 0 ? 'Enter a price to preview your total.' : 'If checked, your total becomes ${fmt(t)}${app.cash > 0 && t > app.cash ? ' (over budget by ${fmt(t - app.cash)})' : ''}', style: ts(11, c: kMut)),
        gap(14),
        bigBtn('Add to list', () {
          if (nameC.text.trim().isEmpty || p <= 0) { toast('Enter a name and price'); return; }
          if (bucket == null) { toast('Add a tag first (+ Add Tag)'); return; }
          app.addItem(nameC.text.trim(), p, qty, bucket!);
          Navigator.pop(context); toast('Added. Tick it to count it');
        }),
      ]);
    });
  }
}

// ---- Edit tags ----
class TagsSheet extends StatefulWidget {
  const TagsSheet({super.key});
  @override
  State<TagsSheet> createState() => _TagsState();
}
class _TagsState extends State<TagsSheet> {
  final tt = TextEditingController();
  String? ren;
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Edit Tag', style: ts(20, w: w7)),
    label(ren != null ? 'Rename tag' : '+ Add Tag'),
    TextField(controller: tt, maxLength: 24, decoration: deco('e.g. Pasabuy ni Baby')),
    gap(8), label('Edit Tags'),
    ConstrainedBox(constraints: const BoxConstraints(minHeight: 90), child: app.buckets.isEmpty
        ? Text('No tags yet. Type a name above and tap Save Tag.', style: ts(11, c: kMut))
        : Wrap(spacing: 10, runSpacing: 6, children: [
      for (final b in app.buckets)
        PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') { setState(() { ren = b; tt.text = b; }); return; }
              final n = app.items.where((x) => x.bucket == b).length;
              final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(backgroundColor: Colors.white,
                  title: const Text('Delete Tag'), content: Text('Delete "$b"${n > 0 ? ' and its $n item${n > 1 ? 's' : ''}' : ''}?'),
                  actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete', style: TextStyle(color: kWr)))]));
              if (ok == true) { app.delTag(b); toast('Tag deleted'); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('✎  Edit Text')),
              PopupMenuItem(value: 'del', child: Text('🗑  Delete Tag', style: TextStyle(color: kWr))),
            ],
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: TagChip(b))),
    ])),
    gap(8),
    bigBtn('Save Tag', () {
      final wasRename = ren != null;
      final err = app.saveTag(tt.text, ren);
      if (err != null) { toast(err); return; }
      tt.clear(); setState(() => ren = null); toast(wasRename ? 'Tag renamed' : 'Tag added');
    }),
    gap(8), bigBtn('Done', () => Navigator.pop(context), white: true),
  ]));
}

// ============================================================
// 10. SPLIT TAB (tag sections → split option → trip splitter)
// ============================================================
class SplitPage extends StatelessWidget {
  const SplitPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) => (app.splitTag != null && app.buckets.contains(app.splitTag)) ? TripSplitter(key: ValueKey(app.splitTag), tag: app.splitTag!) : const SplitHome());
}

class SplitHome extends StatelessWidget {
  const SplitHome({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 110), children: [
    Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text('Split', style: ts(20, w: w6))),
    Text('This tab shows the WHOLE bills, including the parts other people owe you. Home and Lists show only your own share.', style: ts(11, c: kMut)), gap(12),
    if (app.buckets.isEmpty) cardBox(Text('No tags yet. Create tags in Lists → Edit Tag (like McDo or Dorm), then come back to split them.', style: ts(11, c: kMut))),
    for (final b in app.buckets)
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Builder(builder: (_) {
        final s = app.spOf(b), its = app.checked.where((i) => i.bucket == b).toList(), per = app.calcSplit(b).per;
        final coll = per.entries.where((e) => e.key != 'Me').fold(0.0, (a, e) => a + (e.value.total - app.recvOf(b, e.key, e.value.total)));
        return InkWell(onTap: () => s.mode == null ? showSheet(context, SplitModeSheet(b)) : app.openSplit(b), borderRadius: BorderRadius.circular(16),
            child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TagChip(b), Text(s.mode == 'item' ? 'Itemized' : s.mode == 'equal' ? 'Equal split' : 'Not set yet', style: ts(11, c: kMut))]),
              gap(10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fmt(its.fold(0.0, (a, i) => a + i.amt)), style: ts(20, w: w7)), Text('${its.length} checked item${its.length == 1 ? '' : 's'}', style: ts(11, c: kMut)), Text('Your share ${fmt(app.bt(b))}', style: ts(11, w: w6, c: kPr))]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  avStack(s.people, 26), gap(4),
                  Text('${s.people.length} ${s.people.length == 1 ? 'person' : 'people'}${coll > 0 ? ' · to collect ${fmt(coll)}' : ''}', style: ts(11, c: kMut)),
                ]),
              ]),
            ])));
      })),
  ]));
}

class SplitModeSheet extends StatelessWidget {
  final String tag;
  const SplitModeSheet(this.tag, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = app.spOf(tag);
    Widget opt(String m, String t, String d) => Padding(padding: const EdgeInsets.only(top: 10), child: InkWell(
        onTap: () { app.startSplit(tag, m); Navigator.pop(context); }, borderRadius: BorderRadius.circular(14),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: s.mode == m ? const Color(0xFFF4F0FF) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: s.mode == m ? kPr : const Color(0xFFE6E3F2), width: s.mode == m ? 2 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: ts(15, w: w7)), const SizedBox(height: 2), Text(d, style: ts(11, c: kMut))]))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How would you like to split this?', style: ts(20, w: w7)), const SizedBox(height: 2),
          Text('$tag · ${fmt(app.checked.where((i) => i.bucket == tag).fold(0.0, (a, i) => a + i.amt))}', style: ts(13, c: kMut)),
        ])),
        closeBtn(context),
      ]),
      opt('equal', 'Split equally', 'Everything is divided evenly between the people in this tag.'),
      opt('item', 'Itemized split', 'Choose who ordered each item. Only they pay for it.'),
    ]);
  }
}

class TripSplitter extends StatefulWidget {
  final String tag;
  const TripSplitter({super.key, required this.tag});
  @override
  State<TripSplitter> createState() => _TripState();
}
class _TripState extends State<TripSplitter> {
  final open = <String>{};
  @override
  Widget build(BuildContext context) {
    final t = widget.tag, s = app.spOf(t), r = app.calcSplit(t), per = r.per, base = r.base, eq = s.mode == 'equal';
    final items = app.checked.where((i) => i.bucket == t).toList();
    final others = per.keys.where((p) => p != 'Me');
    final collect = others.fold(0.0, (a, p) => a + (per[p]!.total - app.recvOf(t, p, per[p]!.total)));
    final received = others.fold(0.0, (a, p) => a + app.recvOf(t, p, per[p]!.total));
    final toReturn = others.fold(0.0, (a, p) {
      final g = s.given[p] ?? 0, tot = per[p]!.total;
      return a + (((s.paid[p] ?? 0) == 1 && g > tot + 0.005 && s.changed[p] != true) ? g - tot : 0.0);
    });
    return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      titleRow('Trip Splitter', app.backToTags, trailing: softBtn('${eq ? 'Equal' : 'Itemized'} ▾', () => showSheet(context, SplitModeSheet(t)))),
      cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Whole bill · ${items.length} checked items', style: ts(11, c: kMut)), TagChip(t)]),
        Text(fmt(items.fold(0.0, (a, i) => a + i.amt)), style: ts(32, w: w7)),
        Text('Your own share: ${fmt(app.bt(t))}', style: ts(12, w: w6, c: kPr)),
      ]), m: const EdgeInsets.fromLTRB(18, 0, 18, 12), r: 18, p: const EdgeInsets.all(16)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('People in $t', style: ts(15, w: w6)), gap(10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in s.people)
              Container(padding: EdgeInsets.fromLTRB(14, 6, p == 'Me' ? 14 : 4, 6), decoration: BoxDecoration(color: pcOf(p)[0], borderRadius: BorderRadius.circular(18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(p, style: ts(12, w: w6, c: pcOf(p)[1])),
                    if (p != 'Me') InkWell(onTap: () => app.rmPerson(t, p), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.close, size: 14, color: pcOf(p)[1]))),
                  ])),
            InkWell(onTap: () => showSheet(context, PersonSheet(t)), borderRadius: BorderRadius.circular(18),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFEDE4FF), borderRadius: BorderRadius.circular(18)),
                    child: Text('+ Add', style: ts(12, w: w6, c: const Color(0xFF5B2FD0))))),
          ]),
        ])),
        gap(12),
        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Orders', style: ts(15, w: w6)), gap(4),
          Text(eq ? 'Equal split: every item is shared by everyone.' : 'Tap an item to choose who it’s for. A colored bar means only that person pays.', style: ts(11, c: kMut)),
          if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No checked items in this tag yet. Check items on the Lists tab.', style: ts(11, c: kMut))),
          for (final i in items) orderRow(context, i),
        ])),
        gap(12),
        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fees & discounts', style: ts(15, w: w6)), gap(10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Overall discount (₱)', style: ts(11, c: kMut)), gap(4), NumField(key: ValueKey('$t-d'), value: s.disc, onChanged: (v) => app.setDisc(t, v))])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tax / delivery / service (₱)', style: ts(11, c: kMut)), gap(4), NumField(key: ValueKey('$t-f'), value: s.fee, onChanged: (v) => app.setFee(t, v))])),
          ]),
          gap(8), Text('Shared in proportion to what each person ordered.', style: ts(11, c: kMut)),
        ])),
        gap(12),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kInk, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Still to collect', style: ts(12, c: Colors.white)), Text(fmt(collect), style: ts(18, w: w7, c: Colors.white))]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('Received', style: ts(12, c: Colors.white)), Text(fmt(received), style: ts(18, w: w7, c: const Color(0xFF9CF0BC)))]),
              ]),
              if (toReturn > 0) Padding(padding: const EdgeInsets.only(top: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Change to give back', style: ts(12, c: Colors.white)), Text(fmt(toReturn), style: ts(14, w: w7, c: const Color(0xFFFFD27A))),
              ])),
            ])),
        gap(14), Text('Who pays what', style: ts(15, w: w6)), gap(8),
        if (per.isEmpty) cardBox(Text('Check items on the Lists tab to see the split.', style: ts(11, c: kMut))),
        for (final e in per.entries) personCard(t, s, e.key, e.value, base),
      ])),
    ]));
  }

  Widget orderRow(BuildContext context, Item i) {
    final s = app.spOf(i.bucket), P = app.owners(i), each = '${fmt(i.amt / P.length)} each';
    String lab; Color col, bar;
    if (P.length == 1) { lab = 'Only ${P[0]} · not split'; col = bar = pcOf(P[0])[1]; }
    else if (P.length == s.people.length) { lab = 'Everyone · $each'; col = const Color(0xFF4B4B63); bar = const Color(0xFFB8B4CC); }
    else { lab = 'Shared by ${P.join(', ')} · $each'; col = const Color(0xFF4B4B63); bar = const Color(0xFFB8B4CC); }
    return InkWell(
        onTap: () {
          if (s.mode == 'equal') { toast('Switch to Itemized to choose who ordered what'); return; }
          showSheet(context, OwnerSheet(i));
        },
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: IntrinsicHeight(child: Row(children: [
          Container(width: 5, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i.name}${i.qty > 1 ? ' ×${i.qty}' : ''}', style: ts(14, w: w7)), gap(4),
            Row(children: [avStack(P, 24), const SizedBox(width: 10), Expanded(child: Text(lab, style: ts(11, w: w6, c: col)))]),
          ])),
          Text(fmt(i.amt), style: ts(14, w: w7)),
        ]))));
  }

  Widget personCard(String t, SplitCfg s, String p, PerPerson o, double base) {
    final isOpen = open.contains(p), paid = s.paid[p] ?? 0, given = s.given[p] ?? 0, chg = given - o.total;
    void askCash() => showSheet(context, CashGivenSheet(t, p, o.total));
    Widget seg(String txt, int v) {
      final on = paid == v;
      return Expanded(child: InkWell(onTap: () { if (v == 1) { askCash(); } else { app.setPaid(t, p, v); } }, borderRadius: BorderRadius.circular(8),
          child: Container(height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: on ? (v == 0 ? kWr : kPr) : null, borderRadius: BorderRadius.circular(8)),
              child: Text(txt, style: ts(11, w: w6, c: on ? Colors.white : kMut)))));
    }
    Widget chgSeg(String txt, bool v) {
      final on = (s.changed[p] ?? false) == v;
      return Expanded(child: InkWell(onTap: () => app.setChanged(t, p, v), borderRadius: BorderRadius.circular(8),
          child: Container(height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: on ? (v ? kPr : kWr) : null, borderRadius: BorderRadius.circular(8)),
              child: Text(txt, style: ts(11, w: w6, c: on ? Colors.white : kMut)))));
    }
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [dotAv(p, 34), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p, style: ts(15, w: w7)), Text('Subtotal ${fmt(o.sub)}', style: ts(11, c: kMut))])]),
        Text(fmt(o.total), style: ts(17, w: w7)),
      ]),
      InkWell(onTap: () => setState(() { if (isOpen) { open.remove(p); } else { open.add(p); } }), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(isOpen ? 'Hide items ▲' : 'View items ▼', style: ts(12, w: w6, c: kPr)))),
      if (isOpen) ...[
        for (final l in o.lines) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l.name, style: ts(12)), Text(fmt(l.amt), style: ts(12))])),
        const Divider(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount share', style: ts(12)), Text(fmt(base > 0 ? -s.disc * o.sub / base : 0), style: ts(12))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Fee share', style: ts(12)), Text(fmt(base > 0 ? s.fee * o.sub / base : 0), style: ts(12))]),
        gap(6),
      ],
      if (p == 'Me') Text('Your own share, no payment needed.', style: ts(11, c: kMut))
      else Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(10)), child: Row(children: [seg('Unpaid', 0), seg('Cash', 1), seg('GCash received', 2)])),
      if (p != 'Me' && paid == 1 && given > 0) ...[
        gap(8),
        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$p gave ${fmt(given)}', style: ts(12, w: w6)),
            InkWell(onTap: askCash, child: Padding(padding: const EdgeInsets.all(4), child: Text('Edit', style: ts(12, w: w6, c: kPr)))),
          ]),
          gap(4),
          if (chg < -0.005) Text('Short by ${fmt(-chg)}. Still to collect.', style: ts(12, w: w7, c: kWr))
          else if (chg <= 0.005) Text('Exact amount. No change needed.', style: ts(12, c: kMut))
          else ...[
              Text('Change to give back: ${fmt(chg)}', style: ts(15, w: w7)), gap(8),
              Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(10)), child: Row(children: [chgSeg('Change not given', false), chgSeg('Change given ✓', true)])),
            ],
        ]), color: kBg, r: 12, p: const EdgeInsets.all(12)),
      ],
    ])));
  }
}

// ---- Cash handed over by a friend (computes the change) ----
class CashGivenSheet extends StatefulWidget {
  final String tag, person; final double owed;
  const CashGivenSheet(this.tag, this.person, this.owed, {super.key});
  @override
  State<CashGivenSheet> createState() => _GivenState();
}
class _GivenState extends State<CashGivenSheet> {
  late final c = TextEditingController(text: (app.spOf(widget.tag).given[widget.person] ?? 0) > 0 ? numStr(app.spOf(widget.tag).given[widget.person]!) : '');
  double get v => double.tryParse(c.text) ?? 0.0;
  @override
  Widget build(BuildContext context) {
    final chg = v - widget.owed;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How much did ${widget.person} give?', style: ts(20, w: w7)),
          Text('${widget.person} owes ${fmt(widget.owed)}', style: ts(13, c: kMut)),
        ])),
        closeBtn(context),
      ]),
      label('Cash received (₱)'),
      TextField(controller: c, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('0.00'), onChanged: (_) => setState(() {})),
      gap(10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(label: Text('Exact', style: ts(12, w: w6, c: const Color(0xFF5B2FD0))), backgroundColor: const Color(0xFFEDE4FF), side: BorderSide.none,
            onPressed: () => setState(() => c.text = numStr(widget.owed))),
        for (final n in [100, 200, 500, 1000])
          ActionChip(label: Text('₱$n', style: ts(12, w: w6, c: const Color(0xFF5B2FD0))), backgroundColor: const Color(0xFFEDE4FF), side: BorderSide.none,
              onPressed: () => setState(() => c.text = '$n')),
      ]),
      gap(12),
      cardBox(
          Text(v <= 0 ? 'Enter the amount your friend handed you.'
              : chg > 0.005 ? 'Change to give back: ${fmt(chg)}'
              : chg >= -0.005 ? 'Exact amount. No change needed.'
              : 'Short by ${fmt(-chg)}', style: ts(14, w: w7, c: (v > 0 && chg < -0.005) ? kWr : kInk)),
          color: const Color(0xFFF4F0FF), r: 14, p: const EdgeInsets.all(12)),
      gap(14),
      bigBtn('Save', () {
        if (v <= 0) { toast('Enter the amount given'); return; }
        app.setGiven(widget.tag, widget.person, v); Navigator.pop(context);
      }),
    ]);
  }
}

class OwnerSheet extends StatefulWidget {
  final Item item;
  const OwnerSheet(this.item, {super.key});
  @override
  State<OwnerSheet> createState() => _OwnerState();
}
class _OwnerState extends State<OwnerSheet> {
  late List<String> who = (widget.item.who ?? <String>[]).where((p) => app.spOf(widget.item.bucket).people.contains(p)).toList();
  late String mode = who.isEmpty ? 'all' : (who.length == 1 ? 'one' : 'some');
  void pick(String p) => setState(() {
    if (mode == 'all') mode = 'one';
    if (mode == 'one') { who = [p]; } else { if (who.contains(p)) { who.remove(p); } else { who.add(p); } }
  });
  @override
  Widget build(BuildContext context) {
    final it = widget.item, pp = app.spOf(it.bucket).people, P = mode == 'all' ? pp : who;
    Widget opt(String m, String t, String d) => Padding(padding: const EdgeInsets.only(top: 8), child: InkWell(
        onTap: () => setState(() { mode = m; if (m == 'one') who = who.take(1).toList(); }), borderRadius: BorderRadius.circular(14),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: mode == m ? const Color(0xFFF4F0FF) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: mode == m ? kPr : const Color(0xFFE6E3F2), width: mode == m ? 2 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: ts(14, w: w7)), Text(d, style: ts(11, c: kMut))]))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Who ordered this?', style: ts(20, w: w7)), Text('${it.name} · ${fmt(it.amt)}', style: ts(13, c: kMut))])),
        closeBtn(context),
      ]),
      opt('one', 'Only one person', 'The whole price goes to them. Nobody else is charged.'),
      opt('some', 'Shared by some people', 'Pick who shares it. The price is divided between them.'),
      opt('all', 'Everyone', 'Split equally between all ${pp.length} people.'),
      label('Charge to'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in pp)
          InkWell(onTap: () => pick(p), borderRadius: BorderRadius.circular(22),
              child: Container(padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  decoration: BoxDecoration(color: (mode != 'all' && who.contains(p)) ? pcOf(p)[0] : Colors.white, borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: (mode != 'all' && who.contains(p)) ? pcOf(p)[1] : const Color(0xFFE6E3F2), width: (mode != 'all' && who.contains(p)) ? 2 : 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [dotAv(p, 28), const SizedBox(width: 8), Text(p, style: ts(13, w: w6))]))),
      ]),
      gap(14),
      cardBox(
          P.isEmpty
              ? Text('Pick at least one person.', style: ts(13))
              : (mode == 'one'
              ? Text.rich(TextSpan(children: [TextSpan(text: '${fmt(it.amt)} → ${P[0]} only.\n', style: ts(13, w: w7)), TextSpan(text: 'Not included in anyone else’s share.', style: ts(13))]))
              : Text('${fmt(it.amt)} ÷ ${P.length} = ${fmt(it.amt / P.length)} each', style: ts(13, w: w7))),
          color: const Color(0xFFF4F0FF), r: 14, p: const EdgeInsets.all(12)),
      gap(14),
      bigBtn('Done', () {
        if (mode != 'all' && who.isEmpty) { toast('Pick at least one person'); return; }
        app.setOwner(it, mode == 'all' ? null : List.of(who)); Navigator.pop(context);
      }),
    ]);
  }
}

class PersonSheet extends StatefulWidget {
  final String tag;
  const PersonSheet(this.tag, {super.key});
  @override
  State<PersonSheet> createState() => _PersonState();
}
class _PersonState extends State<PersonSheet> {
  final c = TextEditingController();
  void add() {
    final v = c.text.trim();
    if (v.isEmpty) return;
    app.addPerson(widget.tag, v); Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Add person', style: ts(20, w: w7)), label('Name'),
    TextField(controller: c, autofocus: true, maxLength: 20, textCapitalization: TextCapitalization.words, decoration: deco('e.g. Dormate B'), onSubmitted: (_) => add()),
    gap(8), bigBtn('Add', add),
  ]);
}

// ============================================================
// 11. ANALYTICS (only your own money, by date range)
// ============================================================
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final ex = app.an == 'Expenses', rg = app.rng, a = rg.from, b = rg.to, n = spanDays(a, b);
        List<ERow> fetch(String x, String y) => ex ? app.expRows(x, y) : app.incRows(x, y);
        final rows = fetch(a, b), T = rows.fold(0.0, (t, r) => t + r.amt);
        final P = fetch(addD(a, -n), addD(a, -1)).fold(0.0, (t, r) => t + r.amt);
        final ch = P > 0 ? ((T - P) / P * 100).round() : null;
        final bad = ((ch ?? 0) > 0) == ex; // expenses up or income down = bad
        final bars = app.series(a, b, rows);
        var top = 0;
        for (var k = 0; k < bars.length; k++) { if (bars[k].v > bars[top].v) top = k; }
        final groups = ex
            ? (rows.map((r) => r.bucket).toSet().map((k) => Group(k, rows.where((r) => r.bucket == k).fold(0.0, (t, r) => t + r.amt), app.col(k)[1])).where((g) => g.v > 0).toList()..sort((p, q) => q.v.compareTo(p.v)))
            : rows.map((r) => Group(r.name, r.amt, kPr)).toList();
        const presets = {'7d': '7 days', '30d': '30 days', 'month': 'This month', '3m': '3 months', 'custom': 'Custom'};
        Widget seg(String t, bool on, String v) => Expanded(child: InkWell(onTap: () => app.setAn(v), borderRadius: BorderRadius.circular(18),
            child: Container(height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: on ? Colors.white : null, borderRadius: BorderRadius.circular(18)), child: Text(t, style: ts(15, w: w6)))));
        return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 110), children: [
          titleRow('Analytics & Report', () => app.go(0)),
          InkWell(onTap: () => showSheet(c, const RangeSheet()), borderRadius: BorderRadius.circular(16),
              child: cardBox(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Icon(Icons.calendar_month, color: kPr, size: 20), Text(rangeLabel(a, b), style: ts(14, w: w7)), const Text('▾'),
              ]), border: Border.all(color: kPr, width: 1.5), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
          gap(10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final e in presets.entries)
              Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(
                  onTap: () { if (e.key == 'custom') { app.ui(() => app.rng.preset = 'custom'); showSheet(c, const RangeSheet()); } else { app.setPreset(e.key); } },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                      decoration: BoxDecoration(color: rg.preset == e.key ? kInk : Colors.white, borderRadius: BorderRadius.circular(18), border: rg.preset == e.key ? null : Border.all(color: const Color(0xFFE6E3F2))),
                      child: Text(e.value, style: ts(12, w: FontWeight.w500, c: rg.preset == e.key ? Colors.white : kInk))))),
          ])),
          gap(12),
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(22)), child: Row(children: [seg('Expenses', ex, 'Expenses'), seg('Income', !ex, 'Income')])),
          gap(14),
          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total ${ex ? 'expenses' : 'income'} · $n day${n > 1 ? 's' : ''}', style: ts(11, c: kMut)),
            Text(fmt(T), style: ts(30, w: FontWeight.w800)),
            Text('Only your own share of split bills counts here.', style: ts(11, c: kMut)), gap(6),
            Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (app.cmp)
                (ch == null
                    ? Text('No data in the previous period', style: ts(11, c: kMut))
                    : Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: bad ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                    child: Text('${ch > 0 ? '▲' : ch < 0 ? '▼' : '•'} ${ch.abs()}% vs previous $n day${n > 1 ? 's' : ''}', style: ts(12, w: w7, c: bad ? const Color(0xFFB45309) : const Color(0xFF166534))))),
              Text('Avg ${fmt(T / n)} / day', style: ts(11, c: kMut)),
            ]),
          ]), m: const EdgeInsets.only(bottom: 12), p: const EdgeInsets.all(16)),
          if (T > 0) ...[
            cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${ex ? 'Spending' : 'Income'} over time', style: ts(14, w: w7)), Text(n <= 31 ? 'By day' : (n <= 120 ? 'By week' : 'By month'), style: ts(11, c: kMut))]),
              gap(8), SizedBox(height: 136, width: double.infinity, child: CustomPaint(painter: BarsPainter(bars, top))),
              Text('Highest: ${bars[top].label} · ${fmt(bars[top].v)}', style: ts(11, c: kMut)),
            ]), m: const EdgeInsets.only(bottom: 12)),
            cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ex ? 'Where it went' : 'Where it came from', style: ts(14, w: w7)),
              if (ex) Center(child: SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(200, 200), painter: DonutPainter(groups, T)),
                Column(mainAxisSize: MainAxisSize.min, children: [Text('Total', style: ts(10, c: kMut)), Text(fmt(T), style: ts(16, w: w7))]),
              ]))),
              for (final g in groups)
                Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(child: Text.rich(TextSpan(children: [TextSpan(text: g.name, style: ts(13, w: w7)), TextSpan(text: '  ${(g.v / T * 100).round()}% of total', style: ts(11, c: kMut))]))),
                    Text(fmt(g.v), style: ts(14, w: w7)),
                  ]),
                  gap(5), progress((g.v / T * 100).round(), track: g.color.withValues(alpha: .2), fill: g.color),
                ])),
            ])),
          ] else
            cardBox(Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('No data in this range yet. Save a list from Home → date → “Save today’s list”, or pick a wider range.', textAlign: TextAlign.center, style: ts(11, c: kMut))))),
        ]));
      });
}

class BarsPainter extends CustomPainter {
  final List<Bar> bars; final int top;
  BarsPainter(this.bars, this.top);
  @override
  void paint(Canvas c, Size s) {
    if (bars.isEmpty) return;
    final mx = bars.fold<double>(1, (m, b) => math.max(m, b.v));
    final gapW = (s.width - 20) / bars.length, bw = math.min(20.0, gapW - 4), every = (bars.length / 8).ceil(), base = s.height - 26;
    c.drawLine(Offset(8, base), Offset(s.width - 8, base), Paint()..color = kLn..strokeWidth = 1);
    for (var k = 0; k < bars.length; k++) {
      final h = math.max(bars[k].v / mx * (base - 12), 2.0), x = 10 + k * gapW + (gapW - bw) / 2;
      if (bars[k].v > 0) c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, base - h, bw, h), const Radius.circular(3)), Paint()..color = k == top ? kPr : const Color(0xFFCFC2FF));
      if (k % every == 0) {
        final tp = TextPainter(text: TextSpan(text: bars[k].label, style: const TextStyle(fontSize: 9, color: kMut)), textDirection: TextDirection.ltr)..layout();
        tp.paint(c, Offset(x + bw / 2 - tp.width / 2, base + 6));
      }
    }
  }
  @override
  bool shouldRepaint(covariant BarsPainter o) => true;
}

class DonutPainter extends CustomPainter {
  final List<Group> groups; final double total;
  DonutPainter(this.groups, this.total);
  @override
  void paint(Canvas c, Size s) {
    final rect = Rect.fromCircle(center: Offset(s.width / 2, s.height / 2), radius: s.width * 0.35);
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 26..strokeCap = StrokeCap.round;
    final gapA = groups.length > 1 ? 0.45 : 0.0;
    var start = -math.pi / 2;
    for (final g in groups) {
      final sweep = g.v / total * math.pi * 2;
      paint.color = g.color;
      c.drawArc(rect, start + gapA / 2, math.max(0.02, sweep - gapA), false, paint);
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant DonutPainter o) => true;
}

class RangeSheet extends StatelessWidget {
  const RangeSheet({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
    final rg = app.rng, len = spanDays(rg.from, rg.to);
    const pl = {'today': 'Today', '7d': 'Last 7 days', '30d': 'Last 30 days', 'month': 'This month', 'last': 'Last month', '3m': 'Last 3 months', 'year': 'This year', 'custom': 'Custom'};
    Future<void> pick(bool isFrom) async {
      final d = await showDatePicker(context: c, initialDate: toD(isFrom ? rg.from : rg.to), firstDate: DateTime(2020), lastDate: app.now);
      if (d != null) app.setDates(isFrom ? dkey(d) : null, isFrom ? null : dkey(d));
    }
    Widget dateBox(String t, String v, bool isFrom) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: ts(11, c: kMut)), gap(4),
      InkWell(onTap: () => pick(isFrom), borderRadius: BorderRadius.circular(10),
          child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFDDD8F0)), borderRadius: BorderRadius.circular(10)),
              child: Text('${dayLabel(v)}, ${toD(v).year}', style: ts(13, w: w7)))),
    ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Select range', style: ts(20, w: w7)), closeBtn(c)]),
      gap(14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in pl.entries)
          InkWell(onTap: () => e.key == 'custom' ? app.ui(() => rg.preset = 'custom') : app.setPreset(e.key), borderRadius: BorderRadius.circular(18),
              child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                  decoration: BoxDecoration(color: rg.preset == e.key ? const Color(0xFFF4F0FF) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: rg.preset == e.key ? kPr : const Color(0xFFE6E3F2), width: rg.preset == e.key ? 2 : 1)),
                  child: Text(e.value, style: ts(12, w: w7, c: rg.preset == e.key ? const Color(0xFF5B2FD0) : kInk)))),
      ]),
      gap(16),
      Row(children: [dateBox('From', rg.from, true), const SizedBox(width: 10), dateBox('To', rg.to, false)]),
      gap(8), Center(child: Text('$len day${len > 1 ? 's' : ''} selected', style: ts(11, c: kMut))),
      gap(12),
      cardBox(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Compare with previous period', style: ts(13, w: w7)),
          Text(rangeLabel(addD(rg.from, -len), addD(rg.from, -1)), style: ts(11, c: kMut)),
        ])),
        Switch(value: app.cmp, activeThumbColor: Colors.white, activeTrackColor: kPr, onChanged: app.setCmp),
      ]), color: kBg),
      gap(14), bigBtn('Apply range', () => Navigator.pop(c)),
    ]);
  });
}