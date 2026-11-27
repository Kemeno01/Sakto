part of 'main.dart';

class AddChoiceSheet extends StatelessWidget {
  const AddChoiceSheet({super.key});
  @override
  Widget build(BuildContext context) {
    Widget opt(IconData icon, String title, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLn)),
                child: Row(children: [
                  Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: kSel, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: kPrText, size: 22)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(title, style: ts(15, w: w7))),
                  Icon(Icons.chevron_right_rounded, color: kMut),
                ]))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Add to list', style: ts(20, w: w7)),
        closeBtn(context),
      ]),
      gap(4),
      opt(Icons.edit_note_rounded, 'Add manually', () {
        Navigator.pop(context);
        showSheet(shellCtx ?? context, const AddItemSheet());
      }),
      opt(Icons.document_scanner_rounded, 'Scan receipt', () {
        Navigator.pop(context);
        navKey.currentState?.push(MaterialPageRoute(builder: (_) => const ScanReceiptPage()));
      }),
    ]);
  }
}

class _DraftItem {
  String name;
  double price;
  int qty;
  bool keep = true;
  _DraftItem(this.name, this.price, this.qty);
  double get amt => price * qty;
}

class ScanReceiptPage extends StatefulWidget {
  const ScanReceiptPage({super.key});
  @override
  State<ScanReceiptPage> createState() => _ScanReceiptState();
}

class _ScanReceiptState extends State<ScanReceiptPage> {
  final _picker = ImagePicker();
  Uint8List? _photoBytes;
  String _photoMime = 'image/jpeg';
  bool _scanning = false;
  String? _error;
  String? _store;
  double _discount = 0;
  double _fee = 0;
  int _scanSeq = 0;
  List<_DraftItem> _drafts = [];
  String? _tag = (app.sel.length == 1 && app.buckets.contains(app.sel.first))
      ? app.sel.first
      : (app.buckets.isEmpty ? null : app.buckets.first);
  bool _checkOnAdd = true;

  Future<void> _capture(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mime = _detectMime(file);
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoMime = mime;
        _error = null;
        _drafts = [];
        _store = null;
        _discount = 0;
        _fee = 0;
        _scanning = true;
      });
      await _analyzeReceipt(bytes, mime);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Could not open camera/gallery. Check camera permission.';
      });
    }
  }

  String _detectMime(XFile file) {
    final m = file.mimeType;
    if (m != null && m.startsWith('image/')) return m;
    final p = file.path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic') || p.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<Map<String, dynamic>?> _tryEdgeScanner(Uint8List bytes, String mime) async {
    final c = sb;
    if (c == null) return null;
    try {
      final resp = await c.functions
          .invoke('scan-receipt', body: {'imageBase64': base64Encode(bytes), 'mimeType': mime})
          .timeout(const Duration(seconds: 30));
      if (resp.status == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data as Map);
      }
      if (useEdgeScanner) {
        final err = (resp.data is Map) ? (resp.data as Map)['error']?.toString() : null;
        throw Exception(err ?? 'Scanner service error (${resp.status})');
      }
    } catch (e) {
      if (useEdgeScanner || !hasLocalGeminiKey) rethrow;
    }
    return null;
  }

  Future<void> _analyzeReceipt(Uint8List bytes, String mime) async {
    if (!aiReady) {
      setState(() {
        _scanning = false;
        _error = 'Receipt scanner is not configured. Deploy the scan-receipt Supabase Edge Function or run with --dart-define-from-file=secrets.json.';
      });
      return;
    }
    try {
      Map<String, dynamic>? parsed;
      if (useEdgeScanner || !hasLocalGeminiKey) {
        parsed = await _tryEdgeScanner(bytes, mime);
      }
      if (parsed == null) {
        if (!hasLocalGeminiKey) {
          throw Exception('Scanner server unavailable. Deploy the scan-receipt Edge Function or check your connection.');
        }
        const prompt = '''
Extract every purchased item, discount, and extra fee/tax from this receipt image and return ONLY valid JSON in this exact format:
{
  "store": "Short store or restaurant name (optional, max 20 chars)",
  "discount": 0.0,
  "fee": 0.0,
  "items": [
    {"name": "Item name", "price": 100.0, "qty": 1}
  ]
}
Rules:
- "price" MUST be the UNIT price of 1 item as a positive number (e.g. if 2x Sisig costs 230.00 total, set "qty": 2 and "price": 115.0).
- "qty" must be a positive integer (default 1).
- "discount": total discount amount as a positive number (e.g. if receipt shows Discount -110.00, set "discount": 110.0). Use 0 if none.
- "fee": total extra charges added ON TOP of item prices (e.g. Service Charge, Delivery Fee, Packaging Fee, or extra tax added after Subtotal). Do NOT include VAT if it is already included in the item prices (such as Vatable Sale + VAT 12% breakdown). Use 0 if none.
- Ignore subtotals, cash tendered, change, and grand total lines in "items".
- Keep item names clean and readable.
- If no items are readable, return {"store": "", "discount": 0, "fee": 0, "items": []}.
''';
        final body = jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {'inline_data': {'mime_type': mime, 'data': base64Encode(bytes)}},
              ],
            }
          ],
          'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.1},
        });
        final models = [geminiModel, 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-2.5-flash-lite'];
        http.Response? res;
        for (var i = 0; i < models.length; i++) {
          final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${models[i]}:generateContent');
          try {
            res = await http
                .post(
                  uri,
                  headers: {
                    'Content-Type': 'application/json',
                    'x-goog-api-key': geminiApiKey.trim(),
                  },
                  body: body,
                )
                .timeout(const Duration(seconds: 30));
            if (res.statusCode == 200) break;
            if ((res.statusCode == 503 || res.statusCode == 429 || res.statusCode == 404) && i < models.length - 1) continue;
            break;
          } on Exception {
            if (i < models.length - 1) continue;
            rethrow;
          }
        }
        if (res == null || res.statusCode != 200) {
          final msg = res == null ? null : _extractApiError(res.body);
          throw Exception(msg ?? 'AI error (${res?.statusCode ?? 'network'})');
        }
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final parts = ((((decoded['candidates'] as List?)?.first as Map?)?['content'] as Map?)?['parts'] as List?) ?? const [];
        String? text;
        for (final p in parts) {
          if (p is Map && p['thought'] != true && p['text'] is String && (p['text'] as String).trim().isNotEmpty) {
            text = p['text'] as String;
            break;
          }
        }
        if (text == null || text.trim().isEmpty) throw Exception('Empty response from AI');
        var cleaned = text.trim().replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), '').trim();
        final start = cleaned.indexOf('{'), end = cleaned.lastIndexOf('}');
        if (start >= 0 && end > start) cleaned = cleaned.substring(start, end + 1);
        parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      }
      final store = (parsed['store'] as String?)?.trim();
      final discount = math.max(0.0, (parsed['discount'] as num?)?.toDouble() ?? 0.0);
      final fee = math.max(0.0, (parsed['fee'] as num?)?.toDouble() ?? 0.0);
      final rawItems = (parsed['items'] as List?) ?? [];
      final list = <_DraftItem>[];
      for (final x in rawItems) {
        if (x is! Map) continue;
        final name = (x['name'] ?? '').toString().trim();
        final price = (x['price'] as num?)?.toDouble() ?? 0.0;
        final qty = math.max(1, (x['qty'] as num?)?.round() ?? 1);
        if (name.isNotEmpty && price > 0) list.add(_DraftItem(name, price, qty));
      }
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _store = (store != null && store.isNotEmpty) ? store : null;
        _discount = discount;
        _fee = fee;
        _scanSeq++;
        _drafts = list;
        if (list.isEmpty) _error = 'No items detected. Try a clearer photo.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _extractApiError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['error'] as Map?)?['message'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _editDraft(_DraftItem d) {
    final nameC = TextEditingController(text: d.name);
    final priceC = TextEditingController(text: numStr(d.price));
    int q = d.qty;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                title: const Text('Edit scanned item'),
                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
                  TextField(controller: priceC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit price (₱)')),
                  gap(14),
                  Text('Quantity', style: ts(12, w: w6)),
                  gap(6),
                  QtyStepper(q, (v) => setD(() => q = v)),
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: ts(14, c: kMut))),
                  FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: kPr),
                      onPressed: () {
                        final p = double.tryParse(priceC.text);
                        if (nameC.text.trim().isEmpty || p == null || p <= 0) { toast('Check the name and price'); return; }
                        setState(() { d.name = nameC.text.trim(); d.price = p; d.qty = q; });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save')),
                ])));
  }

  void _saveAll() {
    final selected = _drafts.where((d) => d.keep).toList();
    if (selected.isEmpty) { toast('Keep at least one item'); return; }
    if (_tag == null) { toast('Pick or create a tag first'); return; }
    app.addScannedItems(
      selected.map((d) => (d.name, d.price, d.qty)).toList(),
      _tag!,
      checked: _checkOnAdd,
      discount: _discount,
      fee: _fee,
    );
    Navigator.pop(context);
    toast('Added ${selected.length} item${selected.length == 1 ? '' : 's'} to $_tag');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        if (_tag != null && !app.buckets.contains(_tag)) _tag = null;
        final kept = _drafts.where((d) => d.keep).toList();
        final sum = kept.fold(0.0, (a, d) => a + d.amt);
        final netTotal = math.max(0.0, sum + _fee - _discount);
        final canUseStore = _store != null && !app.buckets.contains(_store);
        return Scaffold(
            backgroundColor: kBg,
            body: SafeArea(
                child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                  titleRow('Scan Receipt', () => Navigator.pop(c)),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        cardBox(Column(children: [
                          if (_photoBytes != null) ...[
                            ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(_photoBytes!, height: 170, width: double.infinity, fit: BoxFit.cover)),
                            gap(12),
                          ] else ...[
                            Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Column(children: [
                                  Icon(Icons.receipt_long_rounded, size: 36, color: kMut),
                                  gap(6),
                                  Text('Choose a receipt photo', style: ts(13, w: w6, c: kMut)),
                                ])),
                          ],
                          Row(children: [
                            Expanded(
                                child: ElevatedButton.icon(
                                    onPressed: _scanning ? null : () => _capture(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                    label: Text(_photoBytes == null ? 'Camera' : 'Retake', style: ts(13, w: w6, c: Colors.white)),
                                    style: ElevatedButton.styleFrom(backgroundColor: kPr, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                            const SizedBox(width: 10),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: _scanning ? null : () => _capture(ImageSource.gallery),
                                    icon: Icon(Icons.photo_library_rounded, size: 18, color: kInk),
                                    label: Text('Gallery', style: ts(13, w: w6)),
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: kLn), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                          ]),
                        ])),
                        gap(14),
                        if (_scanning)
                          cardBox(Row(children: [
                            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrText)),
                            const SizedBox(width: 14),
                            Expanded(child: Text('Scanning receipt...', style: ts(13, w: w6))),
                          ])),
                        if (_error != null)
                          cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.error_outline_rounded, color: kWr, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: ts(12, c: kWr))),
                            ]),
                            if (_photoBytes != null) ...[
                              gap(10),
                              softBtn('Try again', () {
                                setState(() { _error = null; _scanning = true; });
                                _analyzeReceipt(_photoBytes!, _photoMime);
                              }),
                            ],
                          ])),
                        if (!_scanning && _drafts.isNotEmpty) ...[

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Scanned items (${kept.length})', style: ts(15, w: w7)),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(fmt(netTotal), style: ts(15, w: w7, c: kPrText)),
                              if (_discount > 0 || _fee > 0) Text('Subtotal ${fmt(sum)}', style: ts(10, c: kMut)),
                            ]),
                          ]),
                          gap(8),
                          cardBox(
                              Column(children: [
                                for (final d in _drafts)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(children: [
                                        InkWell(
                                            onTap: () => setState(() => d.keep = !d.keep),
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                                width: 22, height: 22, alignment: Alignment.center,
                                                decoration: BoxDecoration(color: d.keep ? kPr : null, borderRadius: BorderRadius.circular(6), border: Border.all(color: d.keep ? kPr : kMut, width: 2)),
                                                child: d.keep ? const Icon(Icons.check, size: 14, color: Colors.white) : null)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: InkWell(
                                                onTap: () => _editDraft(d),
                                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  Text(d.name, style: ts(14, w: w6, c: d.keep ? kInk : kMut)),
                                                  Text('${fmt(d.price)} × ${d.qty}', style: ts(11, c: kMut)),
                                                ]))),
                                        Text(fmt(d.amt), style: ts(14, w: w7, c: d.keep ? kInk : kMut)),
                                        IconButton(onPressed: () => _editDraft(d), icon: Icon(Icons.edit_rounded, size: 17, color: kMut), visualDensity: VisualDensity.compact),
                                      ])),
                              ]),
                              p: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                          if (_discount > 0 || _fee > 0) ...[
                            gap(12),
                            cardBox(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Fees & discounts', style: ts(13, w: w7)),
                              gap(8),
                              Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Discount (₱)', style: ts(11, c: kMut)),
                                  gap(4),
                                  NumField(key: ValueKey('sd-$_scanSeq'), value: _discount, onChanged: (v) => setState(() => _discount = v)),
                                ])),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Tax / service (₱)', style: ts(11, c: kMut)),
                                  gap(4),
                                  NumField(key: ValueKey('sf-$_scanSeq'), value: _fee, onChanged: (v) => setState(() => _fee = v)),
                                ])),
                              ]),
                            ])),
                          ],
                          gap(16),

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Choose a tag', style: ts(15, w: w7)),
                            TextButton(
                                onPressed: () async {
                                  await showSheet(c, const TagsSheet());
                                  if (app.lastAdded != null) { setState(() => _tag = app.lastAdded); app.lastAdded = null; }
                                },
                                child: Text('+ New Tag', style: ts(12, w: w6, c: kPrText))),
                          ]),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (canUseStore)
                              ActionChip(
                                  label: Text('+ "$_store"', style: ts(12, w: w6, c: kInk)),
                                  backgroundColor: kBg,
                                  side: BorderSide(color: kLn),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  onPressed: () {
                                    final err = app.saveTag(_store!, null);
                                    if (err == null) { setState(() => _tag = _store); app.lastAdded = null; }
                                  }),
                            for (final b in app.buckets)
                              InkWell(
                                  onTap: () => setState(() => _tag = b),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                      decoration: BoxDecoration(color: _tag == b ? kInk : kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: _tag == b ? kInk : kLn)),
                                      child: Text('#$b', style: ts(12, w: w6, c: _tag == b ? kCard : kInk)))),
                          ]),
                          if (app.buckets.isEmpty && !canUseStore)
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text('No tags yet', style: ts(11, c: kMut))),
                          gap(14),
                          cardBox(
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Expanded(child: Text('Check items automatically', style: ts(13, w: w6))),
                                Switch(value: _checkOnAdd, activeThumbColor: Colors.white, activeTrackColor: kPr, onChanged: (v) => setState(() => _checkOnAdd = v)),
                              ]),
                              p: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
                          gap(16),
                          bigBtn('Add ${kept.length} item${kept.length == 1 ? '' : 's'}${_tag != null ? ' to $_tag' : ''}', _saveAll),
                        ],
                      ])),
                ])));
      });
}
