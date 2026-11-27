part of 'main.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final ex = app.an == 'Expenses', rg = app.rng, a = rg.from, b = rg.to, n = spanDays(a, b);
        final expAll = app.expRows(a, b), incAll = app.incRows(a, b);
        final expTotal = expAll.fold(0.0, (t, r) => t + r.amt);
        final incTotal = incAll.fold(0.0, (t, r) => t + r.amt);
        final net = incTotal - expTotal;
        List<ERow> fetch(String x, String y) => ex ? app.expRows(x, y) : app.incRows(x, y);
        final rows = ex ? expAll : incAll, T = ex ? expTotal : incTotal;
        final P = fetch(addD(a, -n), addD(a, -1)).fold(0.0, (t, r) => t + r.amt);
        final ch = P > 0 ? ((T - P) / P * 100).round() : null;
        final bad = ((ch ?? 0) > 0) == ex;
        final bars = app.series(a, b, rows);
        var top = 0;
        for (var k = 0; k < bars.length; k++) { if (bars[k].v > bars[top].v) top = k; }
        final groups = (rows.map((r) => r.bucket.isEmpty ? 'Other' : r.bucket).toSet().map((k) {
          final col = ex ? app.col(k)[1] : kPal[kIncomeCats.indexOf(k).clamp(0, kPal.length - 1)][1];
          return Group(k, rows.where((r) => (r.bucket.isEmpty ? 'Other' : r.bucket) == k).fold(0.0, (t, r) => t + r.amt), col);
        }).where((g) => g.v > 0).toList()..sort((p, q) => q.v.compareTo(p.v)));
        final incomeItems = ex ? const <Income>[] : app.incEntries(a, b);
        const presets = {'7d': '7 days', '30d': '30 days', 'month': 'This month', '3m': '3 months', 'custom': 'Custom'};
        Widget seg(String t, bool on, String v) => Expanded(child: InkWell(onTap: () => app.setAn(v), borderRadius: BorderRadius.circular(18),
            child: Container(height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: on ? kCard : null, borderRadius: BorderRadius.circular(18)), child: Text(t, style: ts(15, w: w6)))));
        return SafeArea(bottom: false, child: RefreshIndicator(
            color: kPr,
            onRefresh: () async {
              final res = await app.refreshFromCloud();
              if (res == 'offline') { toast('Offline'); }
              else if (res == 'cloud' || res == 'merged') { toast('Synced'); }
            },
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(18, 0, 18, 110), children: [
          titleRow('Analytics & Report', () => app.go(0)),
          InkWell(onTap: () => showSheet(c, const RangeSheet()), borderRadius: BorderRadius.circular(16),
              child: cardBox(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(Icons.calendar_month, color: kPr, size: 20), Text(rangeLabel(a, b), style: ts(14, w: w7)), const Text('▾'),
              ]), border: Border.all(color: kPr, width: 1.5), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
          gap(10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final e in presets.entries)
              Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(
                  onTap: () { if (e.key == 'custom') { app.ui(() => app.rng.preset = 'custom'); showSheet(c, const RangeSheet()); } else { app.setPreset(e.key); } },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                      decoration: BoxDecoration(color: rg.preset == e.key ? kInk : kCard, borderRadius: BorderRadius.circular(18), border: rg.preset == e.key ? null : Border.all(color: kLn)),
                      child: Text(e.value, style: ts(12, w: FontWeight.w500, c: rg.preset == e.key ? kCard : kInk))))),
          ])),
          if (incTotal > 0 || expTotal > 0) ...[
            gap(12),
            cardBox(Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Income', style: ts(10, c: kMut)),
                Text(fmt(incTotal), style: ts(13, w: w7, c: kGreen), overflow: TextOverflow.ellipsis),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expenses', style: ts(10, c: kMut)),
                Text(fmt(expTotal), style: ts(13, w: w7), overflow: TextOverflow.ellipsis),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Net', style: ts(10, c: kMut)),
                Text('${net > 0 ? '+' : ''}${fmt(net)}', style: ts(14, w: w7, c: net >= 0 ? kGreen : kWr), overflow: TextOverflow.ellipsis),
              ])),
            ]), p: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
          ],
          gap(12),
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(22)), child: Row(children: [seg('Expenses', ex, 'Expenses'), seg('Income', !ex, 'Income')])),
          if (!ex) ...[
            gap(10),
            bigBtn('+ Add Income', () => showSheet(c, const AddIncomeSheet())),
          ],
          gap(14),
          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total ${ex ? 'expenses' : 'income'} · $n day${n > 1 ? 's' : ''}', style: ts(11, c: kMut)),
            Text(fmt(T), style: ts(30, w: FontWeight.w800)),
            Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (app.cmp)
                (ch == null
                    ? Text(' ', style: ts(11, c: kMut))
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(ex ? 'Where it went' : 'Where it came from', style: ts(14, w: w7)),
                if (ex)
                  InkWell(
                      onTap: () => showSheet(c, ExpenseDrilldownSheet(title: 'All expenses', range: rangeLabel(a, b), rows: expAll)),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text('See items ›', style: ts(11, w: w6, c: kPrText)))),
              ]),
              Center(child: SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(200, 200), painter: DonutPainter(groups, T)),
                Column(mainAxisSize: MainAxisSize.min, children: [Text('Total', style: ts(10, c: kMut)), Text(fmt(T), style: ts(16, w: w7))]),
              ]))),
              for (final g in groups)
                InkWell(
                    onTap: ex
                        ? () {
                          final filtered = expAll.where((r) => (r.bucket.isEmpty ? 'Other' : r.bucket) == g.name).toList();
                          showSheet(c, ExpenseDrilldownSheet(title: g.name, range: rangeLabel(a, b), rows: filtered));
                        }
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(padding: const EdgeInsets.only(top: 12, bottom: 2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(child: Text.rich(TextSpan(children: [TextSpan(text: g.name, style: ts(13, w: w7)), TextSpan(text: '  ${(g.v / T * 100).round()}%', style: ts(11, c: kMut))]))),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(fmt(g.v), style: ts(14, w: w7)),
                          if (ex) Icon(Icons.chevron_right_rounded, size: 16, color: kMut),
                        ]),
                      ]),
                      gap(5), progress((g.v / T * 100).round(), track: g.color.withValues(alpha: .2), fill: g.color),
                    ]))),
            ])),
            if (!ex && incomeItems.isNotEmpty) ...[
              gap(12),
              cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Income entries (${incomeItems.length})', style: ts(14, w: w7)),
                gap(6),
                for (final item in incomeItems)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.note.isEmpty ? item.cat : '${item.cat} · ${item.note}', style: ts(13, w: w6)),
                          Text(dayLabel(item.d), style: ts(11, c: kMut)),
                        ])),
                        Text(fmt(item.a), style: ts(14, w: w7, c: kGreen)),
                        PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, size: 18, color: kMut),
                            onSelected: (v) {
                              if (v == 'edit') {
                                showSheet(c, AddIncomeSheet(existing: item));
                              } else if (v == 'del') {
                                app.deleteIncome(item);
                                toast('Income entry deleted');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('✎  Edit')),
                              PopupMenuItem(value: 'del', child: Text('🗑  Delete', style: TextStyle(color: kWr))),
                            ]),
                      ])),
              ])),
            ],
          ] else
            cardBox(Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text(
                ex ? 'No expenses in this range' : 'No income in this range',
                textAlign: TextAlign.center, style: ts(11, c: kMut))))),
        ])));
      });
}

class ExpenseDrilldownSheet extends StatelessWidget {
  final String title, range;
  final List<ERow> rows;
  const ExpenseDrilldownSheet({super.key, required this.title, required this.range, required this.rows});

  @override
  Widget build(BuildContext context) {
    final sorted = List.of(rows)..sort((a, b) => b.date.compareTo(a.date));
    final total = sorted.fold(0.0, (a, r) => a + r.amt);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ts(20, w: w7), overflow: TextOverflow.ellipsis),
          Text('$range · ${sorted.length} item${sorted.length == 1 ? '' : 's'}', style: ts(11, c: kMut)),
        ])),
        closeBtn(context),
      ]),
      gap(10),
      cardBox(
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total', style: ts(12, c: kMut)),
            Text(fmt(total), style: ts(18, w: w7, c: kPrText)),
          ]),
          color: kBg,
          p: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      gap(10),
      ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: ListView.separated(
              shrinkWrap: true,
              itemCount: sorted.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: kLn),
              itemBuilder: (_, idx) {
                final r = sorted[idx];
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name, style: ts(14, w: w6)),
                        Text('${dayLabel(r.date)}${title == 'All expenses' && r.bucket.isNotEmpty ? ' · #${r.bucket}' : ''}${r.split ? ' · Shared' : ''}', style: ts(11, c: kMut)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt(r.amt), style: ts(14, w: w7)),
                        if (r.split && (r.full - r.amt).abs() > 0.005) Text('of ${fmt(r.full)}', style: ts(10, c: kMut)),
                      ]),
                    ]));
              })),
    ]);
  }
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
        final tp = TextPainter(text: TextSpan(text: bars[k].label, style: TextStyle(fontSize: 9, color: kMut)), textDirection: TextDirection.ltr)..layout();
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
          child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: kLn), borderRadius: BorderRadius.circular(10)),
              child: Text('${dayLabel(v)}, ${toD(v).year}', style: ts(13, w: w7)))),
    ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Select range', style: ts(20, w: w7)), closeBtn(c)]),
      gap(14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in pl.entries)
          InkWell(onTap: () => e.key == 'custom' ? app.ui(() => rg.preset = 'custom') : app.setPreset(e.key), borderRadius: BorderRadius.circular(18),
              child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                  decoration: BoxDecoration(color: rg.preset == e.key ? kSel : kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: rg.preset == e.key ? kPr : kLn, width: rg.preset == e.key ? 2 : 1)),
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

class AddIncomeSheet extends StatefulWidget {
  final Income? existing;
  const AddIncomeSheet({super.key, this.existing});
  @override
  State<AddIncomeSheet> createState() => _AddIncomeState();
}
class _AddIncomeState extends State<AddIncomeSheet> {
  late final amtC = TextEditingController(text: widget.existing != null ? numStr(widget.existing!.a) : '');
  late final noteC = TextEditingController(text: widget.existing?.note ?? '');
  late String cat = widget.existing?.cat ?? 'Allowance';
  late String date = widget.existing?.d ?? app.today;
  bool addToCash = true;

  @override
  void dispose() {
    amtC.dispose();
    noteC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(editing ? 'Edit Income' : 'Add Income', style: ts(20, w: w7)),
        closeBtn(context),
      ]),
      label('Amount (₱)'),
      TextField(controller: amtC, autofocus: !editing, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: deco('0.00')),
      label('Category'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in kIncomeCats)
          InkWell(
              onTap: () => setState(() => cat = k),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: cat == k ? kPr : kBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: cat == k ? kPr : kLn)),
                  child: Text(k, style: ts(12, w: w6, c: cat == k ? Colors.white : kInk)))),
      ]),
      label('Note (optional)'),
      TextField(controller: noteC, maxLength: 40, textCapitalization: TextCapitalization.sentences, decoration: deco('e.g. Weekly allowance, Client payout')),
      label('Date'),
      InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: toD(date), firstDate: DateTime(2020), lastDate: app.now);
            if (d != null) setState(() => date = dkey(d));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${dayLabel(date)}, ${toD(date).year}', style: ts(13, w: w6)),
                Icon(Icons.calendar_today_rounded, size: 16, color: kPrText),
              ]))),
      if (!editing) ...[
        gap(10),
        cardBox(
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('Also add to Cash on hand', style: ts(13, w: w6))),
              Switch(value: addToCash, activeThumbColor: Colors.white, activeTrackColor: kPr, onChanged: (v) => setState(() => addToCash = v)),
            ]),
            color: kBg,
            p: const EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
      ],
      gap(14),
      bigBtn(editing ? 'Save changes' : 'Save income', () {
        final v = double.tryParse(amtC.text);
        if (v == null || v <= 0) { toast('Enter a valid amount'); return; }
        if (editing) {
          app.editIncome(widget.existing!, v, cat, noteC.text, date);
          toast('Income updated');
        } else {
          app.addIncome(v, cat: cat, note: noteC.text, date: date, addToCash: addToCash);
          toast('Income added');
        }
        Navigator.pop(context);
      }),
    ]);
  }
}
