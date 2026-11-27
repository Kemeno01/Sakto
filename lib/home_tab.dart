part of 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomeState();
}

class _HomeState extends State<HomePage> {
  bool strip = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final left = app.left, warn = app.cash > 0 && left <= app.cash * 0.3, now = app.now;
        final days = [for (var k = -5; k <= 1; k++) addDays(now, k)];
        final latest = app.checked.where((i) => !app.isSplit(i.bucket) || app.owners(i).contains('Me')).toList().reversed.take(3).toList();
        final due = app.dueBills;
        return RefreshIndicator(
            color: kPr,
            onRefresh: () async {
              final res = await app.refreshFromCloud();
              if (res == 'offline') { toast('Offline'); }
              else if (res == 'cloud' || res == 'merged') { toast('Synced'); }
            },
            child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(color: kPr, child: Column(children: [
              Padding(
                  padding: EdgeInsets.fromLTRB(18, MediaQuery.of(c).padding.top + 14, 18, 0),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      InkWell(onTap: () => shellKey.currentState?.openDrawer(), customBorder: const CircleBorder(), child: userAvatar(40)),
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
                    slideReveal(strip, Column(children: [
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
                      gap(6),
                      Center(
                          child: app.hasSavedActiveList
                              ? Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                                ElevatedButton.icon(
                                    onPressed: () => toast(app.saveDay() ? 'Updated today’s list' : 'Check some items first'),
                                    icon: const Icon(Icons.bookmark_added_rounded, size: 17),
                                    label: Text("Update list", style: ts(13, w: w7, c: kPr)),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white, foregroundColor: kPr, elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
                                OutlinedButton.icon(
                                    onPressed: () {
                                      final res = app.saveAndStartNewList();
                                      toast(res == 1
                                          ? 'Saved! Ready for a new list'
                                          : res == 2
                                              ? 'Saved (unsettled splits kept active)'
                                              : 'Check some items first');
                                    },
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 17, color: Colors.white),
                                    label: Text('New list', style: ts(13, w: w7, c: Colors.white)),
                                    style: OutlinedButton.styleFrom(
                                        backgroundColor: kW18, foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))),
                              ])
                              : ElevatedButton.icon(
                                  onPressed: () => toast(app.saveDay() ? 'Saved to spending history' : 'Check some items first'),
                                  icon: const Icon(Icons.bookmark_add_rounded, size: 17),
                                  label: Text(app.hist.containsKey(app.today) ? 'Save as new list' : "Save today's list", style: ts(13, w: w7, c: kPr)),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white, foregroundColor: kPr, elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))))),
                    ])),
                    gap(10),
                    Text('Active total', style: ts(13, c: Colors.white70)),
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
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your Buckets', style: ts(16, w: w6)), gap(10),
                    if (app.buckets.isEmpty)
                      InkWell(
                          onTap: () => showSheet(c, const TagsSheet()),
                          borderRadius: BorderRadius.circular(16),
                          child: cardBox(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Create your first tag', style: ts(13, w: w6)),
                            Icon(Icons.add_rounded, color: kPrText, size: 20),
                          ])))
                    else
                      GridView.count(
                          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.0,
                          children: [
                            for (final b in app.buckets)
                              Builder(builder: (_) {
                                final spent = app.bt(b);
                                final cap = app.bcash[b] ?? 0;
                                final hasCap = cap > 0;
                                final over = hasCap && spent > cap;
                                final bpct = hasCap ? math.min(100, (spent / cap * 100).round()) : 0;
                                return InkWell(
                                    onTap: () { app.sel = {b}; app.go(1); },
                                    borderRadius: BorderRadius.circular(16),
                                    child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      TagChip(b), const Spacer(),
                                      Text(fmt(spent), style: ts(19, w: w7, c: over ? kWr : kInk)),
                                      if (hasCap) ...[
                                        Text(
                                            over ? 'Over by ${fmt(spent - cap)}' : 'of ${fmt(cap)}',
                                            style: ts(10, w: over ? w6 : FontWeight.w400, c: over ? kWr : kMut)),
                                        gap(4),
                                        progress(bpct, track: kLn, fill: over ? kWr : kPr),
                                        gap(4),
                                      ],
                                      Text('${app.bc(b)} items${app.isSplit(b) ? ' · Shared' : ''}', style: ts(10, c: kMut)),
                                      if (app.isSplit(b)) ...[
                                        gap(4),
                                        InkWell(
                                            onTap: () => app.openSplit(b),
                                            child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 2),
                                                child: app.isTagSettled(b)
                                                    ? Text('Settled ✓', style: ts(11, w: w7, c: kGreen))
                                                    : app.tagReceivedRaw(b) > 0
                                                        ? Text('Received ${fmt(app.tagReceivedRaw(b))}', style: ts(11, w: w6, c: kPrText))
                                                        : Text('Unpaid ›', style: ts(10, w: w6, c: kMut)))),
                                      ],
                                    ])));
                              }),
                          ]),
                    if (due.isNotEmpty) ...[
                      gap(18),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Bills due', style: ts(16, w: w6)),
                        TextButton(onPressed: () => showSheet(c, const BillsSheet()), child: Text('Manage', style: ts(12, w: w6, c: kPrText))),
                      ]),
                      gap(4),
                      cardBox(
                          Column(children: [
                            for (final b in due.take(3))
                              Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(b.name, style: ts(14, w: w6)),
                                      Text('Day ${b.dayOfMonth} · #${b.bucket}', style: ts(11, c: b.dayOfMonth <= now.day ? kWr : kMut)),
                                    ])),
                                    Text(fmt(b.amt), style: ts(14, w: w7)),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          app.logBillForCurrentMonth(b);
                                          toast('Logged "${b.name}"');
                                        },
                                        style: OutlinedButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            side: BorderSide(color: kPr),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        child: Text('Log', style: ts(11, w: w6, c: kPrText))),
                                  ])),
                          ]),
                          p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                    ],
                    gap(18), Text('Latest items', style: ts(16, w: w6)), gap(8),
                    cardBox(
                        latest.isEmpty
                            ? Text('No items yet', style: ts(11, c: kMut))
                            : Column(children: [
                          for (final i in latest)
                            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(i.name, style: ts(15, w: w7)), Text('${i.bucket} · checked', style: ts(11, c: kMut))])),
                              Text(fmt(app.myAmt(i)), style: ts(14, w: w7)),
                            ])),
                        ]),
                        p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                  ])),
            ]))));
      });
}

void budgetAlert() {
  final l = app.left;
  toast(app.cash == 0 ? 'Set your cash on hand first' : (l >= 0 ? '${fmt(l)} left of your ${fmt(app.cash)} cap' : 'Over your cap by ${fmt(-l)}'));
}

class CashSheet extends StatefulWidget {
  final String? tag;
  const CashSheet({super.key, this.tag});
  @override
  State<CashSheet> createState() => _CashState();
}
class _CashState extends State<CashSheet> {
  late final double cur = widget.tag == null ? app.cash : (app.bcash[widget.tag] ?? 0);
  late String raw = cur > 0 ? numStr(cur) : '';
  void key(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == '⌫') { if (raw.isNotEmpty) raw = raw.substring(0, raw.length - 1); }
      else if (k == '.') { if (!raw.contains('.')) raw += raw.isEmpty ? '0.' : '.'; }
      else {
        if (raw.contains('.') && raw.split('.')[1].length >= 2) return;
        if (raw.length < 9) raw += k;
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final tg = widget.tag;
    final v = double.tryParse(raw) ?? 0.0, spent = tg == null ? app.total : app.bt(tg), left = v - spent, p = v > 0 ? math.min(100, (spent / v * 100).round()) : 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(tg == null ? 'Cash on hand' : 'Budget · $tg', style: ts(20, w: w7))),
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
              label: Text('+₱$n', style: ts(12, w: w6, c: kPrText)), backgroundColor: kSel, side: BorderSide.none,
              onPressed: () { HapticFeedback.lightImpact(); setState(() => raw = numStr((double.tryParse(raw) ?? 0.0) + n)); })),
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
        final x = raw.isEmpty ? 0.0 : double.tryParse(raw);
        if (x == null || x < 0) { toast('Enter an amount'); return; }
        if (tg == null) { app.saveCash(x); } else { app.saveBucketCash(tg, x); }
        Navigator.pop(context); toast(tg == null ? 'Cash on hand saved' : 'Budget saved for $tg');
      }),
    ]);
  }
}

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
              IconButton(onPressed: () => setState(() => cm = DateTime(y, mo - 1, 1)), icon: Icon(Icons.chevron_left, color: kPr)),
              Text('${kMonths[mo - 1]} $y', style: ts(14, w: w7)),
              IconButton(onPressed: () => setState(() => cm = DateTime(y, mo + 1, 1)), icon: Icon(Icons.chevron_right, color: kPr)),
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
                          Text('$d', style: ts(13, w: saved ? w7 : FontWeight.w500, c: sel ? Colors.white : kInk)),
                          if (saved) Icon(Icons.circle, size: 4, color: sel ? Colors.white : kPr),
                        ])));
              }),
          ]),
          gap(6),
          Row(children: [Icon(Icons.circle, size: 5, color: kPr), const SizedBox(width: 4), Text('Saved day', style: ts(11, c: kMut))]),
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
            ] else ...[
              Text('No saved list on ${dayLabel(cd)}.', style: ts(11, c: kMut)),
              gap(10),
              bigBtn('+ Log expense for this day', () => historyItemDialog(context, cd), white: true),
            ],
          ]), color: kBg, r: 18),
        ]);
      });
}

class DayPage extends StatelessWidget {
  final String k;
  const DayPage(this.k, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final H = app.hist[k];
        if (H == null) {
          return Scaffold(
              backgroundColor: kBg,
              body: SafeArea(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                titleRow(dayLabel(k), () => Navigator.pop(c)),
                Padding(
                    padding: const EdgeInsets.all(18),
                    child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('No saved items for this day.', style: ts(13, c: kMut)),
                      gap(12),
                      bigBtn('+ Add expense', () => historyItemDialog(c, k)),
                    ]))),
              ])));
        }
        final rows = H.rows, sp = H.sum;
        final parts = rows.map((r) => r.bucket).toSet().map((b) => MapEntry(b, rows.where((r) => r.bucket == b).fold(0.0, (a, r) => a + r.own))).where((e) => e.value > 0).toList();
        return Scaffold(
            backgroundColor: kBg,
            body: SafeArea(child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
              titleRow(
                dayLabel(k),
                () => Navigator.pop(c),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  softBtn('+ Add', () => historyItemDialog(c, k)),
                  const SizedBox(width: 6),
                  IconButton(
                      tooltip: 'Delete saved day',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                            context: c,
                            builder: (d) => AlertDialog(
                                backgroundColor: kCard,
                                title: const Text('Delete saved day?'),
                                content: Text('Remove all saved items from ${dayLabel(k)}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete', style: TextStyle(color: kWr))),
                                ]));
                        if (ok == true) {
                          app.deleteHistoryDay(k);
                          if (c.mounted) Navigator.pop(c);
                          toast('Saved day deleted');
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded, color: kWr, size: 22)),
                ]),
              ),
              cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('You spent', style: ts(11, c: kMut)),
                Text.rich(TextSpan(children: [TextSpan(text: fmt(sp), style: ts(30, w: w7)), TextSpan(text: ' / ${fmt(H.cap)}', style: ts(11, c: kMut))])),
                gap(8), segBar([for (final p in parts) MapEntry(app.col(p.key)[1], p.value)]), gap(8),
                Wrap(spacing: 12, runSpacing: 4, children: [for (final p in parts) Text('● ${p.key} ${fmt(p.value)}', style: ts(11, c: app.col(p.key)[1]))]),
                gap(8),
                Text(H.cap >= sp ? '${fmt(H.cap - sp)} under budget' : '${fmt(sp - H.cap)} over budget', style: ts(11, w: w6, c: H.cap >= sp ? const Color(0xFF14683A) : kWr)),
              ]), m: const EdgeInsets.symmetric(horizontal: 18), r: 18, p: const EdgeInsets.all(16)),
              gap(12),
              for (var li = 0; li < H.lists.length; li++) ...[
                if (li > 0) gap(10),
                cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (H.lists.length > 1)
                    Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 4),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('List ${li + 1}', style: ts(12, w: w7, c: kMut)),
                          Text(fmt(H.lists[li].fold(0.0, (a, x) => a + x.own)), style: ts(12, w: w7, c: kPrText)),
                        ])),
                  for (var ri = 0; ri < H.lists[li].length; ri++)
                    Builder(builder: (_) {
                      final r = H.lists[li][ri];
                      final listIdx = li, rowIdx = ri, dayCap = H.cap;
                      void deleteRow() {
                        app.deleteHistoryItem(k, listIdx, rowIdx);
                        toast('Deleted "${r.name}"', actionLabel: 'Undo', onAction: () => app.restoreHistoryItem(k, listIdx, rowIdx, r, cap: dayCap));
                      }
                      return Dismissible(
                          key: ValueKey('hist-$k-$li-$ri-${r.name}-${r.own}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(color: kWr, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22)),
                          onDismissed: (_) {
                            HapticFeedback.mediumImpact();
                            deleteRow();
                          },
                          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                            Icon(Icons.check_box, color: kPr.withValues(alpha: .6), size: 22), const SizedBox(width: 10),
                            Expanded(child: Text(r.name, style: ts(14, w: FontWeight.w500))), const SizedBox(width: 6), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: TagChip(r.bucket)), const SizedBox(width: 6),
                            Text(fmt(r.own), textAlign: TextAlign.right, style: ts(13, w: w7)),
                            PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: 18, color: kMut),
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    historyItemDialog(c, k, listIndex: listIdx, rowIndex: rowIdx, existing: r);
                                  } else if (v == 'del') {
                                    deleteRow();
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('✎  Edit')),
                                  PopupMenuItem(value: 'del', child: Text('🗑  Delete', style: TextStyle(color: kWr))),
                                ]),
                          ])));
                    }),
                ]), m: const EdgeInsets.symmetric(horizontal: 18), r: 18, p: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
              ],
              Padding(padding: const EdgeInsets.all(18), child: Column(children: [
                bigBtn('Reuse for today', () { app.reuse(k); Navigator.popUntil(c, (r) => r.isFirst); toast('Items copied to today’s list'); }),
                gap(8),
                bigBtn('Back to calendar', () {
                  Navigator.pop(c);
                  final sc = shellCtx;
                  if (sc != null && sc.mounted) showSheet(sc, CalendarSheet(initial: k));
                }, white: true),
              ])),
            ])));
      });
}

void historyItemDialog(BuildContext c, String dayKey, {int listIndex = 0, int? rowIndex, HRow? existing}) {
  final nameC = TextEditingController(text: existing?.name ?? '');
  final amtC = TextEditingController(text: existing != null ? numStr(existing.own) : '');
  final tagChoices = <String>{...app.buckets, ...app.tagTemplates}.toList();
  String tag = existing?.bucket ?? (tagChoices.isNotEmpty ? tagChoices.first : 'General');
  final customTagC = TextEditingController();
  showDialog(
      context: c,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
              backgroundColor: kCard,
              title: Text(existing == null ? 'Log expense · ${dayLabel(dayKey)}' : 'Edit history item'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: nameC, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Item name')),
                TextField(controller: amtC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₱)')),
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
                        onSelected: (_) => setD(() { tag = b; customTagC.clear(); })),
                ]),
                gap(8),
                TextField(
                    controller: customTagC,
                    decoration: const InputDecoration(labelText: 'Or type a new tag', isDense: true),
                    onChanged: (v) { if (v.trim().isNotEmpty) setD(() => tag = v.trim()); }),
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kPr),
                    onPressed: () {
                      final n = nameC.text.trim();
                      final a = double.tryParse(amtC.text);
                      final finalTag = customTagC.text.trim().isNotEmpty ? customTagC.text.trim() : tag;
                      if (n.isEmpty || a == null || a <= 0 || finalTag.isEmpty) {
                        toast('Enter a valid name, amount, and tag');
                        return;
                      }
                      if (existing != null && rowIndex != null) {
                        app.editHistoryItem(dayKey, listIndex, rowIndex, n, a, finalTag);
                        toast('History item updated');
                      } else {
                        app.addHistoryItem(dayKey, n, a, finalTag, listIndex: listIndex);
                        toast('Expense logged to ${dayLabel(dayKey)}');
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save')),
              ])));
}
