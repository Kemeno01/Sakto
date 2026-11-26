part of 'main.dart';

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
        final bad = ((ch ?? 0) > 0) == ex;
        final bars = app.series(a, b, rows);
        var top = 0;
        for (var k = 0; k < bars.length; k++) { if (bars[k].v > bars[top].v) top = k; }
        final groups = ex
            ? (rows.map((r) => r.bucket).toSet().map((k) => Group(k, rows.where((r) => r.bucket == k).fold(0.0, (t, r) => t + r.amt), app.col(k)[1])).where((g) => g.v > 0).toList()..sort((p, q) => q.v.compareTo(p.v)))
            : rows.map((r) => Group(r.name, r.amt, kPr)).toList();
        const presets = {'7d': '7 days', '30d': '30 days', 'month': 'This month', '3m': '3 months', 'custom': 'Custom'};
        Widget seg(String t, bool on, String v) => Expanded(child: InkWell(onTap: () => app.setAn(v), borderRadius: BorderRadius.circular(18),
            child: Container(height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: on ? kCard : null, borderRadius: BorderRadius.circular(18)), child: Text(t, style: ts(15, w: w6)))));
        return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 110), children: [
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
          gap(12),
          Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: kLn, borderRadius: BorderRadius.circular(22)), child: Row(children: [seg('Expenses', ex, 'Expenses'), seg('Income', !ex, 'Income')])),
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
