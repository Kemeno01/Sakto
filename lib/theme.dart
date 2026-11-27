part of 'main.dart';

const kWr = Color(0xFFC2410C);

bool get isDark => app.dark;
Color get kPr => isDark ? const Color(0xFF4B2896) : const Color(0xFF7B4DEB);
Color get kPrText => isDark ? const Color(0xFFB794FF) : const Color(0xFF7B4DEB);
Color get kGreen => isDark ? const Color(0xFF4ADE80) : const Color(0xFF14683A);
Color get kLil => isDark ? const Color(0xFF6B42C2) : const Color(0xFF9B6BFF);
Color get kInk => isDark ? const Color(0xFFEDEAF6) : const Color(0xFF1B1630);
Color get kMut => isDark ? const Color(0xFFA8A2BD) : const Color(0xFF6B6580);
Color get kBg => isDark ? const Color(0xFF110F18) : const Color(0xFFF6F5F9);
Color get kLn => isDark ? const Color(0xFF2B2738) : const Color(0xFFEEECF3);
Color get kCard => isDark ? const Color(0xFF1C1927) : Colors.white;
Color get kSel => isDark ? const Color(0xFF2F2650) : const Color(0xFFF4F0FF);
Color get kDeep => isDark ? const Color(0xFF2A2340) : const Color(0xFF1B1630);
const kW18 = Color(0x2EFFFFFF), kW35 = Color(0x59FFFFFF);
const w6 = FontWeight.w600, w7 = FontWeight.w700;
const kMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const kWd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

const List<List<Color>> kPal = [
  [Color(0xFFEDE4FF), Color(0xFF5B2FD0)], [Color(0xFFDDF3E6), Color(0xFF14683A)],
  [Color(0xFFFFE6D6), Color(0xFFA04100)], [Color(0xFFDCEBFF), Color(0xFF0B57B5)],
  [Color(0xFFFFF3C9), Color(0xFF7A5A00)], [Color(0xFFFFE0F0), Color(0xFFA0155F)],
  [Color(0xFFE3E8FF), Color(0xFF2F3FA8)], [Color(0xFFD9F5F2), Color(0xFF0B6B63)],
];

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

void toast(String m, {String? actionLabel, VoidCallback? onAction}) {
  final o = navKey.currentState?.overlay;
  if (o == null) return;
  late OverlayEntry e;
  Timer? timer;
  var removed = false;
  void dismiss() {
    if (!removed) {
      removed = true;
      timer?.cancel();
      e.remove();
    }
  }
  final hasAction = actionLabel != null && onAction != null;
  final pill = Material(
      color: const Color(0xFF1B1630),
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: Padding(
          padding: EdgeInsets.fromLTRB(16, hasAction ? 4 : 10, hasAction ? 8 : 16, hasAction ? 4 : 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
            if (hasAction) ...[
              const SizedBox(width: 8),
              TextButton(
                  onPressed: () {
                    dismiss();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB794FF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
          ])));
  e = OverlayEntry(
      builder: (_) => Positioned(
          left: 20,
          right: 20,
          bottom: 110,
          child: hasAction ? Center(child: pill) : IgnorePointer(child: Center(child: pill))));
  o.insert(e);
  timer = Timer(Duration(milliseconds: hasAction ? 3600 : 1900), dismiss);
}

TextStyle ts(double s, {FontWeight w = FontWeight.w400, Color? c}) => TextStyle(fontSize: s, fontWeight: w, color: c ?? kInk);
Widget gap(double h) => SizedBox(height: h);

Widget slideReveal(bool open, Widget child) => TweenAnimationBuilder<double>(
    tween: Tween(end: open ? 1.0 : 0.0),
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    builder: (_, t, c) => t == 0 ? const SizedBox(width: double.infinity) : ClipRect(child: Align(alignment: Alignment.topCenter, heightFactor: t, child: Opacity(opacity: t, child: c))),
    child: child);

Widget cardBox(Widget child, {EdgeInsets p = const EdgeInsets.all(14), EdgeInsets m = EdgeInsets.zero, Color? color, double r = 16, Border? border}) =>
    Container(margin: m, padding: p, decoration: BoxDecoration(color: color ?? kCard, borderRadius: BorderRadius.circular(r), border: border), child: child);

Widget progress(int pct, {Color track = kW35, Color fill = Colors.white}) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: SizedBox(height: 6, child: Stack(fit: StackFit.expand, children: [
      ColoredBox(color: track),
      Align(alignment: Alignment.centerLeft, child: AnimatedFractionallySizedBox(duration: const Duration(milliseconds: 250), curve: Curves.easeOut, widthFactor: (pct / 100).clamp(0.0, 1.0), heightFactor: 1.0, child: ColoredBox(color: fill))),
    ])));

Widget bigBtn(String t, VoidCallback f, {bool white = false, Color? bg}) => SizedBox(
    width: double.infinity, height: 50,
    child: ElevatedButton(
        onPressed: f,
        style: ElevatedButton.styleFrom(
            backgroundColor: bg ?? (white ? kCard : kPr), foregroundColor: white ? kInk : Colors.white, elevation: 0,
            side: white ? BorderSide(color: kLn) : null, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kLn, width: 1),
      ),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '#', style: ts(10, w: w7, c: kMut)),
          TextSpan(text: ' $b', style: ts(11, w: w6, c: kInk)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
}

Widget dotAv(String p, double z, {bool border = true}) {
  final bytes = app.personPhotoBytes(p);
  final netUrl = (p == 'Me' && bytes == null) ? app.avatarUrl : null;
  final placeholder = Icon(Icons.person_rounded, size: z * 0.58, color: kMut);
  Widget child;
  if (bytes != null) {
    child = Image.memory(bytes, width: z, height: z, fit: BoxFit.cover, gaplessPlayback: true);
  } else if (netUrl != null) {
    child = Image.network(netUrl, width: z, height: z, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
  } else {
    child = placeholder;
  }
  return Container(
      width: z,
      height: z,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF2B2738) : const Color(0xFFE9E7F0),
        border: border ? Border.all(color: kCard, width: 1.5) : null,
      ),
      child: child);
}

Widget avStack(List<String> ps, double z) {
  final l = ps.take(4).toList();
  if (l.isEmpty) return const SizedBox.shrink();
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
  void dispose() {
    c.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => TextField(
      controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(hintText: '0', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      onChanged: (v) => widget.onChanged(math.max(0.0, double.tryParse(v) ?? 0.0)));
}

Future<T?> showSheet<T>(BuildContext c, Widget child) => showModalBottomSheet<T>(
    context: c, isScrollControlled: true, useSafeArea: true, backgroundColor: kCard,
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
    child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: kLn, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18)));

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
      ?trailing,
    ]));

Widget softBtn(String t, VoidCallback f) => OutlinedButton(
    onPressed: f,
    style: OutlinedButton.styleFrom(backgroundColor: kCard, foregroundColor: kMut, side: BorderSide(color: kLn), minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    child: Text(t, style: ts(11, w: w6, c: kMut)));
