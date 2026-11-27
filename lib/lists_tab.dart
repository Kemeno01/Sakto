part of 'main.dart';

class ListsPage extends StatefulWidget {
  const ListsPage({super.key});
  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  late final TextEditingController _searchC = TextEditingController(text: app.listQuery);

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        final S = app.sel;
        final q = app.listQuery.trim().toLowerCase();
        var L = app.items.where((i) => (S.isEmpty || S.contains(i.bucket)) && (q.isEmpty || i.name.toLowerCase().contains(q) || i.bucket.toLowerCase().contains(q))).toList();
        switch (app.listSort) {
          case 'az': L.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); break;
          case 'hi': L.sort((a, b) => app.myAmt(b).compareTo(app.myAmt(a))); break;
          case 'lo': L.sort((a, b) => app.myAmt(a).compareTo(app.myAmt(b))); break;
          case 'unchecked': L.sort((a, b) => (a.checked ? 1 : 0).compareTo(b.checked ? 1 : 0)); break;
        }
        final t = app.selTotal(), cap = app.selCash, left = cap - t, pct = cap > 0 ? math.min(100, (t / cap * 100).round()) : 0;
        Item? next;
        if (cap > 0) { for (final i in L) { if (!i.checked && app.myAmt(i) > left) { next = i; break; } } }
        Widget chip(String b, bool on, VoidCallback f) => Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(onTap: f, borderRadius: BorderRadius.circular(18),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? kInk : kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? kInk : kLn)),
                child: Text(b, style: ts(12, w: on ? w6 : FontWeight.w500, c: on ? kCard : kInk)))));
        final pageTitle = S.isEmpty ? 'Lists' : (S.length == 1 ? S.first : '${S.length} Tags');
        final singleTag = S.length == 1 ? S.first : null;
        final singleCfg = singleTag != null ? app.sp[singleTag] : null;
        final singleBase = singleTag != null ? app.gross(singleTag) : 0.0;
        final singleDisc = singleCfg != null ? app.effDisc(singleCfg, singleBase) : 0.0;
        final singleFee = singleCfg != null ? app.effFee(singleCfg, singleBase) : 0.0;
        final hasAdj = singleCfg != null && (singleCfg.scVatExempt || singleCfg.disc > 0 || singleCfg.fee > 0);
        final checkedCount = L.where((i) => i.checked).length;
        final allChecked = L.isNotEmpty && checkedCount == L.length;
        void openBudget() {
          if (S.isEmpty) {
            showSheet(c, const CashSheet());
          } else if (S.length == 1) {
            showSheet(c, CashSheet(tag: S.first));
          } else {
            showDialog(
                context: c,
                builder: (ctx) => SimpleDialog(
                    backgroundColor: kCard,
                    title: const Text('Set Tag Budget'),
                    children: [
                      for (final b in S)
                        SimpleDialogOption(
                            onPressed: () {
                              Navigator.pop(ctx);
                              showSheet(c, CashSheet(tag: b));
                            },
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              TagChip(b),
                              Text(fmt(app.bcash[b] ?? 0), style: ts(13, w: w6)),
                            ])),
                    ]));
          }
        }
        return SafeArea(bottom: false, child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
          titleRow(pageTitle, () => app.go(0), trailing: softBtn('Edit Tag', () => showSheet(c, const TagsSheet()))),
          SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 18), children: [
            chip('All', S.isEmpty, app.clearSel),
            for (final b in app.buckets) chip(b, S.contains(b), () => app.toggleSel(b)),
          ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: InkWell(
                  onTap: openBudget,
                  borderRadius: BorderRadius.circular(18),
                  child: cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(child: Text(S.isEmpty ? 'Total · All Tags' : 'Total · ${S.join(' + ')}', style: ts(11, c: kMut), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text(
                          S.isEmpty
                              ? (cap > 0 ? 'Cash on hand ›' : 'Set cash ›')
                              : (S.length == 1 ? (cap > 0 ? 'Edit budget ›' : 'Set budget ›') : 'Edit budgets ›'),
                          style: ts(11, w: w6, c: kPrText)),
                    ]),
                    Text.rich(TextSpan(children: [TextSpan(text: fmt(t), style: ts(30, w: w7)), TextSpan(text: ' / ${fmt(cap)}', style: ts(11, c: kMut))])),
                    if (hasAdj) ...[
                      gap(4),
                      InkWell(
                          onTap: () => tagFeesDialog(c, singleTag!),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                [
                                  if (singleDisc > 0.005 || singleCfg.scVatExempt) '−${fmt(singleDisc)} disc',
                                  if (singleFee > 0.005) '+${fmt(singleFee)} fee',
                                ].join(' · '),
                                style: ts(11, w: w6, c: kMut)),
                            const SizedBox(width: 6),
                            Text('Edit', style: ts(11, w: w6, c: kPrText)),
                          ])),
                    ],
                    gap(6), progress(pct, track: const Color(0xFFE5DBFF), fill: kPr),
                  ]), r: 18, p: const EdgeInsets.all(16)))),
          if (app.items.isNotEmpty)
            Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(children: [
                  Expanded(
                      child: SizedBox(
                          height: 40,
                          child: TextField(
                              controller: _searchC,
                              style: ts(13),
                              onChanged: app.setListQuery,
                              decoration: InputDecoration(
                                  hintText: 'Search items...',
                                  hintStyle: ts(12, c: kMut),
                                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: kMut),
                                  suffixIcon: app.listQuery.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: Icon(Icons.close_rounded, size: 16, color: kMut),
                                          onPressed: () { _searchC.clear(); app.setListQuery(''); }),
                                  filled: true,
                                  fillColor: kCard,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kLn)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: kLn)))))),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                      tooltip: 'Sort items',
                      onSelected: app.setListSort,
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'default', child: Text('Default order${app.listSort == 'default' ? ' ✓' : ''}')),
                        PopupMenuItem(value: 'unchecked', child: Text('Unchecked first${app.listSort == 'unchecked' ? ' ✓' : ''}')),
                        PopupMenuItem(value: 'az', child: Text('Name A–Z${app.listSort == 'az' ? ' ✓' : ''}')),
                        PopupMenuItem(value: 'hi', child: Text('Price: High → Low${app.listSort == 'hi' ? ' ✓' : ''}')),
                        PopupMenuItem(value: 'lo', child: Text('Price: Low → High${app.listSort == 'lo' ? ' ✓' : ''}')),
                      ],
                      child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: app.listSort == 'default' ? kCard : kSel, borderRadius: BorderRadius.circular(14), border: Border.all(color: app.listSort == 'default' ? kLn : kPr)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.sort_rounded, size: 17, color: app.listSort == 'default' ? kInk : kPrText),
                            const SizedBox(width: 4),
                            Text('Sort', style: ts(12, w: w6, c: app.listSort == 'default' ? kInk : kPrText)),
                          ]))),
                ])),
          if (next != null)
            cardBox(Text('Heads up: adding ${next.name} puts you ${fmt(t + app.myAmt(next) - cap)} over budget.', style: ts(12, c: Colors.white)), color: kWr, r: 14, m: const EdgeInsets.fromLTRB(18, 0, 18, 12), p: const EdgeInsets.all(12)),
          cardBox(
              L.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(app.buckets.isEmpty ? 'No tags yet' : (q.isNotEmpty ? 'No items match "$q"' : 'No items yet'), style: ts(11, c: kMut)))
                  : Column(children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 2),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('$checkedCount of ${L.length} checked', style: ts(11, c: kMut)),
                          InkWell(
                              onTap: () { HapticFeedback.lightImpact(); app.setAllChecked(L, !allChecked); },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(allChecked ? 'Uncheck all' : 'Check all', style: ts(11, w: w6, c: kPrText)))),
                        ])),
                    Divider(height: 1, color: kLn),
                    for (final i in L) ItemRow(i),
                  ]),
              m: const EdgeInsets.symmetric(horizontal: 18), r: 18, p: const EdgeInsets.symmetric(horizontal: 14)),
        ]));
      });
}

void _deleteWithUndo(Item i) {
  final idx = app.items.indexOf(i);
  app.delItem(i);
  toast('Deleted "${i.name}"', actionLabel: 'Undo', onAction: () => app.restoreItem(i, idx));
}

class ItemRow extends StatelessWidget {
  final Item i;
  const ItemRow(this.i, {super.key});
  @override
  Widget build(BuildContext context) => Dismissible(
      key: ValueKey('item-${i.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(color: kWr, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22)),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _deleteWithUndo(i);
      },
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            InkWell(onTap: () { HapticFeedback.lightImpact(); app.toggle(i); }, borderRadius: BorderRadius.circular(7),
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
              if ((app.myAmt(i) - i.amt).abs() > 0.005)
                Text('of ${fmt(i.amt)} · ${app.isSplit(i.bucket) ? 'shared' : 'w/ fee/disc'}', style: ts(10, c: kMut)),
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
          ])));
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
      TextButton(onPressed: () { Navigator.pop(ctx); _deleteWithUndo(i); }, child: const Text('Yes', style: TextStyle(color: kWr))),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
    ]));

void tagFeesDialog(BuildContext c, String tag) {
  final s = app.spOf(tag);
  final discC = TextEditingController(text: s.disc > 0 ? numStr(s.disc) : '');
  final feeC = TextEditingController(text: s.fee > 0 ? numStr(s.fee) : '');
  showDialog(
      context: c,
      builder: (ctx) => AlertDialog(
          backgroundColor: kCard,
          title: Text('Fees & discounts · $tag'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: discC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Overall discount (₱)')),
            TextField(controller: feeC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax / service fee (₱)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kPr),
                onPressed: () {
                  app.setDisc(tag, math.max(0.0, double.tryParse(discC.text) ?? 0.0));
                  app.setFee(tag, math.max(0.0, double.tryParse(feeC.text) ?? 0.0));
                  Navigator.pop(ctx);
                  toast('Tag fees & discounts updated');
                },
                child: const Text('Save')),
          ]));
}

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
  void dispose() {
    nameC.dispose();
    priceC.dispose();
    super.dispose();
  }

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
        else Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in app.buckets)
            InkWell(onTap: () => setState(() => bucket = b), borderRadius: BorderRadius.circular(10),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: bucket == b ? kInk : kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bucket == b ? kInk : kLn),
                    ),
                    child: Text('#$b', style: ts(12, w: bucket == b ? w7 : FontWeight.w500, c: bucket == b ? kCard : kInk)))),
        ]),
        if (p > 0) ...[
          gap(12),
          Text('New total: ${fmt(t)}${app.cash > 0 && t > app.cash ? ' (over by ${fmt(t - app.cash)})' : ''}', style: ts(11, c: kMut)),
        ],
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
  void dispose() { tt.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (c, _) {
    final availTemplates = app.tagTemplates.where((t) => !app.buckets.contains(t)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Edit Tag', style: ts(20, w: w7)),
      label(ren != null ? 'Rename tag' : '+ Add Tag'),
      TextField(controller: tt, maxLength: 24, decoration: deco('e.g. Mall Trip')),
      if (availTemplates.isNotEmpty) ...[
        gap(4),
        label('Templates'),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final tmpl in availTemplates)
            InputChip(
                label: Text('+ $tmpl', style: ts(11, w: w6, c: kInk)),
                backgroundColor: kBg,
                side: BorderSide(color: kLn),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                deleteIcon: Icon(Icons.close_rounded, size: 14, color: kMut),
                onDeleted: () => app.rmTagTemplate(tmpl),
                onPressed: () {
                  app.saveTag(tmpl, null);
                  toast('Added "$tmpl"');
                }),
        ]),
      ],
      gap(8), label('Your Tags'),
      ConstrainedBox(constraints: const BoxConstraints(minHeight: 70), child: app.buckets.isEmpty
          ? Text('No tags yet', style: ts(11, c: kMut))
          : Wrap(spacing: 10, runSpacing: 6, children: [
        for (final b in app.buckets)
          PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') { setState(() { ren = b; tt.text = b; }); return; }
                if (v == 'budget') { await showSheet(context, CashSheet(tag: b)); return; }
                if (v == 'template') {
                  final err = app.addTagTemplate(b);
                  toast(err ?? 'Saved "$b" as template');
                  return;
                }
                final n = app.items.where((x) => x.bucket == b).length;
                final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(backgroundColor: kCard,
                    title: const Text('Delete Tag'), content: Text('Delete "$b"${n > 0 ? ' and its $n item${n > 1 ? 's' : ''}' : ''}?'),
                    actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete', style: TextStyle(color: kWr)))]));
                if (ok == true) { app.delTag(b); toast('Tag deleted'); }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('✎  Edit Text')),
                const PopupMenuItem(value: 'budget', child: Text('₱  Set Budget')),
                if (!app.tagTemplates.contains(b)) const PopupMenuItem(value: 'template', child: Text('★  Save as Template')),
                const PopupMenuItem(value: 'del', child: Text('🗑  Delete Tag', style: TextStyle(color: kWr))),
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
    ]);
  });
}
