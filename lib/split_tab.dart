part of 'main.dart';

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
    if (app.buckets.isEmpty) cardBox(Text('No tags created.', style: ts(11, c: kMut))),
    for (final b in app.buckets)
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Builder(builder: (_) {
        final s = app.spOf(b), its = app.checked.where((i) => i.bucket == b).toList(), per = app.calcSplit(b).per;
        final coll = per.entries.fold(0.0, (a, e) => a + (e.value.total - app.recvOf(b, e.key, e.value.total)));
        return InkWell(onTap: () => s.mode == null ? showSheet(context, SplitModeSheet(b)) : app.openSplit(b), borderRadius: BorderRadius.circular(16),
            child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TagChip(b), Text(s.mode == 'item' ? 'Itemized' : s.mode == 'equal' ? 'Equal split' : 'Not set yet', style: ts(11, c: kMut))]),
              gap(10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(fmt(its.fold(0.0, (a, i) => a + i.amt)), style: ts(20, w: w7)), Text('Your Total ${fmt(app.bt(b))}', style: ts(11, w: w6, c: kPr))]),
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
    Widget opt(String m, String t) => Padding(padding: const EdgeInsets.only(top: 10), child: InkWell(
        onTap: () { app.startSplit(tag, m); Navigator.pop(context); }, borderRadius: BorderRadius.circular(14),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: s.mode == m ? kSel : kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: s.mode == m ? kPr : kLn, width: s.mode == m ? 2 : 1)),
            child: Text(t, style: ts(15, w: w7)))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Splitting Option', style: ts(20, w: w7)), const SizedBox(height: 2),
          Text('$tag · ${fmt(app.checked.where((i) => i.bucket == tag).fold(0.0, (a, i) => a + i.amt))}', style: ts(13, c: kMut)),
        ])),
        closeBtn(context),
      ]),
      opt('equal', 'Split equally'),
      opt('item', 'Itemized split'),
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
    final payers = per.keys;
    final collect = payers.fold(0.0, (a, p) => a + (per[p]!.total - app.recvOf(t, p, per[p]!.total)));
    final received = payers.fold(0.0, (a, p) => a + app.recvOf(t, p, per[p]!.total));
    final toReturn = payers.fold(0.0, (a, p) {
      final g = s.given[p] ?? 0, tot = per[p]!.total;
      return a + (((s.paid[p] ?? 0) == 1 && g > tot + 0.005 && s.changed[p] != true) ? g - tot : 0.0);
    });
    return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      titleRow('Trip Splitter', app.backToTags, trailing: softBtn('${eq ? 'Equal' : 'Itemized'} ▾', () => showSheet(context, SplitModeSheet(t)))),
      cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Whole bill', style: ts(11, c: kMut)), TagChip(t)]),
        Text(fmt(items.fold(0.0, (a, i) => a + i.amt)), style: ts(32, w: w7)),
        Text('Your Total: ${fmt(app.bt(t))}', style: ts(12, w: w6, c: kPr)),
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
          if (items.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('No checked items.', style: ts(11, c: kMut))),
          for (final i in items) orderRow(context, i),
        ])),
        gap(12),
        cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fees & discounts', style: ts(15, w: w6)), gap(10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Overall discount (₱)', style: ts(11, c: kMut)), gap(4), NumField(key: ValueKey('$t-d'), value: s.disc, onChanged: (v) => app.setDisc(t, v))])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tax / service (₱)', style: ts(11, c: kMut)), gap(4), NumField(key: ValueKey('$t-f'), value: s.fee, onChanged: (v) => app.setFee(t, v))])),
          ]),
          gap(8),
        ])),
        gap(12),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: kDeep, borderRadius: BorderRadius.circular(16)),
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
    else if (P.length == s.people.length) { lab = 'Everyone · $each'; col = kMut; bar = const Color(0xFFB8B4CC); }
    else { lab = 'Shared by ${P.join(', ')} · $each'; col = kMut; bar = const Color(0xFFB8B4CC); }
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
      slideReveal(isOpen, Column(children: [
        for (final l in o.lines) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l.name, style: ts(12)), Text(fmt(l.amt), style: ts(12))])),
        const Divider(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Discount share', style: ts(12)), Text(fmt(base > 0 ? -s.disc * o.sub / base : 0), style: ts(12))]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Fee share', style: ts(12)), Text(fmt(base > 0 ? s.fee * o.sub / base : 0), style: ts(12))]),
        gap(6),
      ])),
      Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(10)), child: Row(children: [seg('Unpaid', 0), seg('Cash', 1), seg('GCash received', 2)])),
      slideReveal(paid == 1 && given > 0, Column(children: [
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
      ])),
    ])));
  }
}

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
          color: kSel, r: 14, p: const EdgeInsets.all(12)),
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
    Widget opt(String m, String t) => Padding(padding: const EdgeInsets.only(top: 8), child: InkWell(
        onTap: () => setState(() { mode = m; if (m == 'one') who = who.take(1).toList(); }), borderRadius: BorderRadius.circular(14),
        child: Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: mode == m ? kSel : kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: mode == m ? kPr : kLn, width: mode == m ? 2 : 1)),
            child: Text(t, style: ts(14, w: w7)))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Who ordered this?', style: ts(20, w: w7)), Text('${it.name} · ${fmt(it.amt)}', style: ts(13, c: kMut))])),
        closeBtn(context),
      ]),
      opt('one', 'Only one person'),
      opt('some', 'Shared by some people'),
      opt('all', 'Everyone'),
      label('Charge to'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in pp)
          InkWell(onTap: () => pick(p), borderRadius: BorderRadius.circular(22),
              child: Container(padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  decoration: BoxDecoration(color: (mode != 'all' && who.contains(p)) ? pcOf(p)[0] : kCard, borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: (mode != 'all' && who.contains(p)) ? pcOf(p)[1] : kLn, width: (mode != 'all' && who.contains(p)) ? 2 : 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [dotAv(p, 28), const SizedBox(width: 8), Text(p, style: ts(13, w: w6))]))),
      ]),
      gap(14),
      cardBox(
          P.isEmpty
              ? Text('Pick at least one person.', style: ts(13))
              : (mode == 'one'
              ? Text.rich(TextSpan(children: [TextSpan(text: '${fmt(it.amt)} → ${P[0]} only.\n', style: ts(13, w: w7)), TextSpan(text: 'Not included in anyone else’s share.', style: ts(13))]))
              : Text('${fmt(it.amt)} ÷ ${P.length} = ${fmt(it.amt / P.length)} each', style: ts(13, w: w7))),
          color: kSel, r: 14, p: const EdgeInsets.all(12)),
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
