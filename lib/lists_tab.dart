part of 'main.dart';

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
                decoration: BoxDecoration(color: on ? kInk : kCard, borderRadius: BorderRadius.circular(18)),
                child: Text(b, style: ts(12, w: FontWeight.w500, c: on ? kCard : kInk)))));
        return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
          titleRow('Weekend grocery', () => app.go(0), trailing: softBtn('Edit Tag', () => showSheet(c, const TagsSheet()))),
          SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
            chip('All', S.isEmpty, app.clearSel),
            for (final b in app.buckets) chip(b, S.contains(b), () => app.toggleSel(b)),
          ])),
          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.isEmpty ? 'Total · All Tags' : 'Total · ${S.join(' + ')}', style: ts(11, c: kMut)),
            Text.rich(TextSpan(children: [TextSpan(text: fmt(t), style: ts(30, w: w7)), TextSpan(text: ' / ${fmt(cap)}', style: ts(11, c: kMut))])),
            gap(6), progress(pct, track: const Color(0xFFE5DBFF), fill: kPr),

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
            icon: Icon(Icons.more_horiz, color: kInk),
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
      backgroundColor: kCard, title: const Text('Edit Item'),
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
    backgroundColor: kCard, title: const Text('Change Category'),
    children: app.buckets.isEmpty
        ? [const Padding(padding: EdgeInsets.all(20), child: Text('No tags yet. Create one with Edit Tag.'))]
        : [for (final b in app.buckets) SimpleDialogOption(onPressed: () { app.setCat(i, b); Navigator.pop(ctx); }, child: Align(alignment: Alignment.centerLeft, child: TagChip(b)))]));

void delDialog(BuildContext c, Item i) => showDialog(context: c, builder: (ctx) => AlertDialog(
    backgroundColor: kCard, title: const Text('Delete Item'), content: Text('Delete "${i.name}"?'),
    actions: [
      TextButton(onPressed: () { app.delItem(i); Navigator.pop(ctx); toast('Item deleted'); }, child: const Text('Yes', style: TextStyle(color: kWr))),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
    ]));

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
                    decoration: BoxDecoration(color: bucket == b ? kSel : null, borderRadius: BorderRadius.circular(20)),
                    child: Text(b, style: ts(12, w: bucket == b ? w7 : FontWeight.w500)))),
        ]),
        gap(12),
        Text(p <= 0 ? 'Enter a price to preview your total.' : 'If checked, your total becomes ${fmt(t)}${app.cash > 0 && t > app.cash ? ' (over budget by ${fmt(t - app.cash)})' : ''}', style: ts(11, c: kMut)),
        gap(14),
        bigBtn('Add to list', () {
          if (nameC.text.trim().isEmpty || p <= 0) { toast('Enter a name and price'); return; }
          if (bucket == null) { toast('Add a tag first (+ Add Tag)'); return; }
          app.addItem(nameC.text.trim(), p, qty, bucket!);
          Navigator.pop(context); toast('Item added! Check the box to include it');
        }),
      ]);
    });
  }
}

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
    TextField(controller: tt, maxLength: 24, decoration: deco('e.g. Mall Trip')),
    gap(8), label('Edit Tags'),
    ConstrainedBox(constraints: const BoxConstraints(minHeight: 90), child: app.buckets.isEmpty
        ? Text('No tags yet. Type a name above and tap Save Tag.', style: ts(11, c: kMut))
        : Wrap(spacing: 10, runSpacing: 6, children: [
      for (final b in app.buckets)
        PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') { setState(() { ren = b; tt.text = b; }); return; }
              final n = app.items.where((x) => x.bucket == b).length;
              final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(backgroundColor: kCard,
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
