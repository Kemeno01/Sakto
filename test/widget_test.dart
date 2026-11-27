import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sakto/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await app.clearProfile(erase: true);
  });

  testWidgets('LandingPage renders when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(const SpentApp());
    expect(find.text('Sakto'), findsOneWidget);
    expect(find.text('Continue offline'), findsOneWidget);
  });

  testWidgets('Lists tab shows dynamic title, search, bulk actions, and opens per-tag CashSheet', (WidgetTester tester) async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Food', null);
    app.addItem('Ramen', 250, 1, 'Food');
    app.addItem('Gyoza', 150, 1, 'Food');
    app.toggle(app.items.first);
    app.go(1);

    await tester.pumpWidget(const SpentApp());
    await tester.pumpAndSettle();

    expect(find.text('Weekend grocery'), findsNothing);
    expect(find.text('← Lists'), findsOneWidget);
    expect(find.text('1 of 2 checked'), findsOneWidget);

    // Bulk check all
    await tester.tap(find.text('Check all'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 checked'), findsOneWidget);
    expect(find.text('Uncheck all'), findsOneWidget);

    // Filter to Food tag -> title updates and tapping budget card opens CashSheet(tag: 'Food')
    app.toggleSel('Food');
    await tester.pumpAndSettle();
    expect(find.text('← Food'), findsOneWidget);
    expect(find.text('Set budget ›'), findsOneWidget);

    await tester.tap(find.text('Set budget ›'));
    await tester.pumpAndSettle();
    expect(find.text('Budget · Food'), findsOneWidget);

    await tester.tap(find.text('+₱500'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save cash on hand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save cash on hand'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(app.bcash['Food'], 500.0);
    expect(app.selCash, 500.0);
  });

  test('openSplit switches to Split tab without clearing splitTag', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Dinner', null);
    app.startSplit('Dinner', 'equal');
    app.go(0);
    expect(app.tab, 0);

    app.openSplit('Dinner');
    expect(app.tab, 2);
    expect(app.splitTag, 'Dinner');

    app.go(2);
    expect(app.splitTag, isNull);
  });

  test('Non-split scanned discounts & fees apply and clamp at zero', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Groceries', null);
    app.addScannedItems(
      [('Rice', 300, 1), ('Eggs', 200, 1)],
      'Groceries',
      checked: true,
      discount: 100,
      fee: 50,
    );

    expect(app.isSplit('Groceries'), isFalse);
    expect(app.bt('Groceries'), closeTo(450.0, 0.01));
    expect(app.total, closeTo(450.0, 0.01));

    app.setDisc('Groceries', 900);
    expect(app.bt('Groceries'), 0.0);

    app.startSplit('Groceries', 'equal');
    app.addPerson('Groceries', 'Ana');
    final split = app.calcSplit('Groceries');
    expect(split.per['Me']!.total, 0.0);
    expect(split.per['Ana']!.total, 0.0);
  });

  test('PH Split math: % service charge, 20% SC/PWD VAT-exempt, paidBy, and formatted summary', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.savePaymentDetails(gcashName: 'Juan D.', gcashNumber: '09171234567', mayaNumber: '09189998888');
    app.saveTag('Dinner', null);
    app.addItem('Seafood Platter', 1120, 1, 'Dinner');
    app.toggle(app.items.first);
    app.startSplit('Dinner', 'equal');
    app.addPerson('Dinner', 'Carlo');

    // +10% service charge on 1120 = +112 -> 1232 total (616 each)
    app.setFeePct('Dinner', true);
    app.setFee('Dinner', 10);
    var res = app.calcSplit('Dinner');
    expect(res.per['Me']!.total, closeTo(616.0, 0.01));
    expect(res.per['Carlo']!.total, closeTo(616.0, 0.01));

    // Exact PH 20% SC/PWD VAT-exempt on 1120: 1120 / 1.12 = 1000 vatable -> 20% off = 800 (+ 112 service = 912 -> 456 each)
    app.setScVatExempt('Dinner', true);
    expect(app.effDisc(app.spOf('Dinner'), 1120), closeTo(320.0, 0.01));
    res = app.calcSplit('Dinner');
    expect(res.per['Me']!.total, closeTo(456.0, 0.01));
    expect(res.per['Carlo']!.total, closeTo(456.0, 0.01));

    // Summary includes GCash & Maya when Me paid the bill
    final summaryMe = app.formatSplitSummary('Dinner');
    expect(summaryMe, contains('Dinner Split Summary'));
    expect(summaryMe, contains('Paid by: Me'));
    expect(summaryMe, contains('SC/PWD 20% VAT-ex'));
    expect(summaryMe, contains('GCash: 09171234567 (Juan D.)'));
    expect(summaryMe, contains('Maya: 09189998888 (Juan D.)'));

    // Switching Paid By to Carlo still tracks Carlo's cash given & change in group totals
    app.setPaidBy('Dinner', 'Carlo');
    expect(app.isTagSettled('Dinner'), isFalse);
    app.setPaid('Dinner', 'Me', 2); // Me paid via GCash
    expect(app.isTagSettled('Dinner'), isFalse); // Carlo hasn't recorded his cash/change yet
    app.setGiven('Dinner', 'Carlo', 500); // Carlo gave ₱500 for his ₱456 share -> ₱44 change
    expect(app.isTagSettled('Dinner'), isFalse); // Change not marked given yet
    app.setChanged('Dinner', 'Carlo', true);
    expect(app.isTagSettled('Dinner'), isTrue);
    expect(app.tagReceivedRaw('Dinner'), closeTo(912.0, 0.01));
    final summaryCarlo = app.formatSplitSummary('Dinner');
    expect(summaryCarlo, contains('Paid by: Carlo'));
    expect(summaryCarlo, contains('Carlo (Counter)'));
    expect(summaryCarlo, contains('change ₱44.00 ✓'));
    expect(summaryCarlo, isNot(contains('GCash: 09171234567')));
  });

  test('Counter payer cash given and change count toward group split total', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Lunch', null);
    app.startSplit('Lunch', 'item');
    app.addPerson('Lunch', 'Carlo');
    app.setPaidBy('Lunch', 'Carlo');

    app.addItem('Chicken Meal', 115, 1, 'Lunch');
    app.toggle(app.items.last);
    app.setOwner(app.items.last, ['Carlo']);

    app.addItem('Burger', 120, 1, 'Lunch');
    app.toggle(app.items.last);
    app.setOwner(app.items.last, ['Me']);

    // Carlo (counter payer) ordered ₱115 and put in ₱150 cash -> ₱35 change
    app.setGiven('Lunch', 'Carlo', 150);
    final per = app.calcSplit('Lunch').per;
    final received = per.keys.fold(0.0, (a, p) => a + app.recvOf('Lunch', p, per[p]!.total));
    final collect = per.keys.fold(0.0, (a, p) => a + (per[p]!.total - app.recvOf('Lunch', p, per[p]!.total)));
    expect(received, closeTo(115.0, 0.01));
    expect(collect, closeTo(120.0, 0.01));
    expect(app.tagReceivedRaw('Lunch'), closeTo(150.0, 0.01));
    expect(app.isTagSettled('Lunch'), isFalse);

    // After change is returned and Me pays, the split settles cleanly
    app.setChanged('Lunch', 'Carlo', true);
    app.setPaid('Lunch', 'Me', 2);
    expect(app.isTagSettled('Lunch'), isTrue);
    expect(app.tagReceivedRaw('Lunch'), closeTo(235.0, 0.01));
  });

  test('Persistent friends and tag templates survive clearActiveList', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Work Lunch', null);
    app.addTagTemplate('Work Lunch');
    app.startSplit('Work Lunch', 'equal');
    app.addPerson('Work Lunch', 'Mika');

    app.clearActiveList();
    expect(app.buckets, isEmpty);
    expect(app.allPeople, contains('Mika'));
    expect(app.tagTemplates, contains('Work Lunch'));
  });

  test('Past day history supports backdating, editing, and deleting', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    final past = addD(app.today, -3);

    // Backdate an expense onto a day with no saved list
    app.addHistoryItem(past, 'Grab ride', 180, 'Transpo');
    expect(app.hist[past]!.rows.length, 1);
    expect(app.hist[past]!.sum, closeTo(180.0, 0.01));

    // Edit item
    app.editHistoryItem(past, 0, 0, 'GrabCar', 220, 'Transpo');
    expect(app.hist[past]!.rows.first.name, 'GrabCar');
    expect(app.hist[past]!.sum, closeTo(220.0, 0.01));

    // Delete item cleans up empty day
    app.deleteHistoryItem(past, 0, 0);
    expect(app.hist.containsKey(past), isFalse);

    // Delete whole day
    app.addHistoryItem(past, 'Coffee', 140, 'Food');
    app.deleteHistoryDay(past);
    expect(app.hist.containsKey(past), isFalse);
  });

  test('Categorized income tracking supports add, edit, delete, and legacy JSON', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.addIncome(5000, cat: 'Allowance', note: 'Weekly', addToCash: true);
    expect(app.cash, 5000.0);
    expect(app.inc.length, 1);
    expect(app.incRows(app.today, app.today).first.bucket, 'Allowance');

    app.editIncome(app.inc.first, 6000, 'Salary', 'Mid-month', app.today);
    expect(app.inc.first.a, 6000.0);
    expect(app.inc.first.cat, 'Salary');

    // Legacy 2-element Income JSON still parses safely
    final legacy = Income.fromJson([app.today, 250]);
    expect(legacy.cat, 'Cash top-up');
    expect(legacy.a, 250.0);

    app.deleteIncome(app.inc.first);
    expect(app.inc, isEmpty);
  });

  test('CSV export and JSON backup/restore round-trip cleanly', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Food', null);
    app.addItem('Sisig, Special', 250, 1, 'Food');
    app.toggle(app.items.first);
    app.addIncome(1000, cat: 'Allowance', note: 'Mom');
    app.addSavedFriend('Bea');

    final csv = app.exportCsv();
    expect(csv, contains('Date,Type,Tag/Category,Item/Note,Full Amount,My Share,Split'));
    expect(csv, contains('"Sisig, Special"'));
    expect(csv, contains('Income,Allowance,Mom,1000.00'));

    final backup = app.exportBackupJson();
    app.resetAll();
    expect(app.items, isEmpty);
    expect(app.inc, isEmpty);

    expect(app.importBackupJson('not json'), isNotNull);
    expect(app.importBackupJson(backup), isNull);
    expect(app.items.length, 1);
    expect(app.inc.length, 1);
    expect(app.allPeople, contains('Bea'));
  });

  test('Offline to Google migration merges local data without losing cloud data', () async {
    await app.setProfile(id: 'local_juan', name: 'Juan', mode: 'local');
    final yesterday = addD(app.today, -1);
    app.saveTag('Snacks', null);
    app.addHistoryItem(yesterday, 'Chips', 65, 'Snacks');
    app.addSavedFriend('Marco');
    final offlineData = app.toJson();

    // Switch to a Google account that already has its own tag/history
    await app.setProfile(id: 'google_123', name: 'Juan', email: 'juan@example.com', mode: 'google');
    app.saveTag('Bills', null);
    final merged = await app.mergeDataMap(offlineData);

    expect(merged, isTrue);
    expect(app.buckets, containsAll(['Bills', 'Snacks']));
    expect(app.hist[yesterday]!.rows.first.name, 'Chips');
    expect(app.allPeople, contains('Marco'));
  });

  test('Multiple lists per day append cleanly and Analytics stays fresh', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveCash(2000);
    app.saveTag('Food', null);
    app.addItem('Coffee', 120, 1, 'Food');
    app.toggle(app.items.first);

    expect(app.saveDay(), isTrue);
    expect(app.hist[app.today]!.lists.length, 1);
    expect(app.hasSavedActiveList, isTrue);

    app.addItem('Lunch', 200, 1, 'Food');
    app.toggle(app.items.last);
    final rowsLive = app.expRows(app.today, app.today);
    expect(rowsLive.fold(0.0, (a, r) => a + r.amt), closeTo(320.0, 0.01));

    expect(app.saveAndStartNewList(), 1);
    expect(app.hist[app.today]!.lists.length, 1);
    expect(app.checked, isEmpty);
    expect(app.buckets, contains('Food'));

    app.addItem('Dinner', 350, 1, 'Food');
    app.toggle(app.items.last);
    final rowsWithList2 = app.expRows(app.today, app.today);
    expect(rowsWithList2.fold(0.0, (a, r) => a + r.amt), closeTo(670.0, 0.01));

    expect(app.saveDay(), isTrue);
    expect(app.hist[app.today]!.lists.length, 2);
    final rowsAfterSave2 = app.expRows(app.today, app.today);
    expect(rowsAfterSave2.fold(0.0, (a, r) => a + r.amt), closeTo(670.0, 0.01));
  });

  test('Midnight rollover preserves tags, budgets, unchecked items, friends, and unsettled splits', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    final yesterday = addD(app.today, -1);
    app.activeDay = yesterday;
    app.saveCash(1500);

    app.saveTag('Food', null);
    app.saveBucketCash('Food', 600);
    app.addItem('Burger', 150, 1, 'Food');
    app.toggle(app.items.last);
    app.addItem('Milk', 90, 1, 'Food');

    app.saveTag('Dinner', null);
    app.startSplit('Dinner', 'equal');
    app.addPerson('Dinner', 'Carlo');
    app.addItem('Sisig', 400, 1, 'Dinner');
    app.toggle(app.items.last);

    app.saveTag('Coffee', null);
    app.startSplit('Coffee', 'equal');
    app.addPerson('Coffee', 'Bea');
    app.addItem('Latte', 300, 1, 'Coffee');
    app.toggle(app.items.last);
    app.setPaid('Coffee', 'Me', 2);
    app.setPaid('Coffee', 'Bea', 2);
    expect(app.isTagSettled('Coffee'), isTrue);

    expect(app.rolloverIfNeeded(), isTrue);
    expect(app.activeDay, app.today);

    expect(app.cash, 1500.0);
    expect(app.buckets, containsAll(['Food', 'Dinner', 'Coffee']));
    expect(app.bcash['Food'], 600.0);
    expect(app.sp['Coffee']!.people, contains('Bea'));
    expect(app.sp['Dinner']!.people, contains('Carlo'));

    expect(app.items.any((i) => i.name == 'Milk' && !i.checked), isTrue);
    expect(app.items.any((i) => i.name == 'Sisig' && i.checked), isTrue);
    expect(app.hist[yesterday]!.rows.any((r) => r.name == 'Sisig'), isFalse);

    expect(app.items.any((i) => i.name == 'Burger'), isFalse);
    expect(app.items.any((i) => i.name == 'Latte'), isFalse);
    expect(app.hist[yesterday]!.rows.any((r) => r.name == 'Burger'), isTrue);
    expect(app.hist[yesterday]!.rows.any((r) => r.name == 'Latte'), isTrue);
    expect(app.sp['Coffee']!.paid, isEmpty);

    final rows = app.expRows(yesterday, app.today);
    expect(rows.fold(0.0, (a, r) => a + r.amt), closeTo(500.0, 0.01));
  });

  testWidgets('Friend photos persist and tapping friend name in drawer opens photo editor', (WidgetTester tester) async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.addSavedFriend('Carlo');
    expect(app.personPhotoBytes('Carlo'), isNull);

    // Save and restore a custom photo in backup JSON
    final sampleBytes = Uint8List.fromList([1, 2, 3, 4]);
    app.setPersonPhoto('Carlo', sampleBytes);
    expect(app.personPhotoBytes('Carlo'), sampleBytes);
    final backup = app.exportBackupJson();
    app.clearPersonPhoto('Carlo');
    expect(app.personPhotoBytes('Carlo'), isNull);
    expect(app.importBackupJson(backup), isNull);
    expect(app.personPhotoBytes('Carlo'), sampleBytes);

    // Clear photo to verify default no-photo placeholder renders in Drawer and tapping name opens editor
    app.clearPersonPhoto('Carlo');
    await tester.pumpWidget(const SpentApp());
    await tester.pumpAndSettle();

    shellKey.currentState?.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Carlo'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsWidgets);

    await tester.tap(find.text('Carlo'));
    await tester.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  test('LocalStore v2 migrates legacy v1 blob into partitioned keys and erases cleanly', () async {
    final legacyData = {
      'activeDay': app.today,
      'cash': 750.0,
      'buckets': ['Food'],
      'items': [Item(1, 'Taho', 25, 'Food', checked: true).toJson()],
      'inc': [Income(app.today, 750, cat: 'Allowance').toJson()],
      'personPhotos': {'Carlo': base64Encode([9, 8, 7])},
      'hist': {
        '2026-10-15': HistDay(500, [[HRow('Coffee', 120, 'Food')]]).toJson(),
        '2026-11-20': HistDay(800, [[HRow('Lunch', 250, 'Food')]]).toJson(),
      },
    };
    SharedPreferences.setMockInitialValues({
      'sakto-data-v1-local_legacy': jsonEncode(legacyData),
    });

    final loaded = await LocalStore.loadAccount('local_legacy');
    expect(loaded, isNotNull);
    expect((loaded!['hist'] as Map).keys, containsAll(['2026-10-15', '2026-11-20']));

    final prefs = await SharedPreferences.getInstance();
    // Legacy v1 key removed; partitioned v2 keys created
    expect(prefs.getString('sakto-data-v1-local_legacy'), isNull);
    expect(prefs.getString('sakto-v2-local_legacy-meta'), isNotNull);
    expect(prefs.getString('sakto-v2-local_legacy-inc'), isNotNull);
    expect(prefs.getString('sakto-v2-local_legacy-photos'), isNotNull);
    expect(prefs.getStringList('sakto-v2-local_legacy-hist-index'), ['2026-10', '2026-11']);

    await LocalStore.eraseAccount('local_legacy');
    expect(prefs.getString('sakto-v2-local_legacy-meta'), isNull);
    expect(prefs.getString('sakto-v2-local_legacy-hist-2026-10'), isNull);
  });

  test('Cloud sync conflict resolution preserves newer offline edits and merges concurrent changes', () async {
    await app.setProfile(id: 'google_sync_test', name: 'Juan', email: 'j@test.com', mode: 'google');
    app.saveTag('OfflineTag', null);
    app.addItem('Offline Item', 99, 1, 'OfflineTag');
    await app.save(allPartitions: true);

    final newerLocalTs = DateTime.utc(2026, 11, 27, 12, 0, 0);
    final olderCloudTs = DateTime.utc(2026, 11, 27, 11, 0, 0);
    final newerCloudTs = DateTime.utc(2026, 11, 27, 13, 0, 0);
    app.lastModifiedIso = newerLocalTs.toIso8601String();
    app.pendingCloudSync = true;

    // 1. Older cloud snapshot must NOT overwrite newer pending local edits
    final olderCloud = CloudSnapshot({
      'updatedAt': olderCloudTs.toIso8601String(),
      'buckets': ['OldCloudTag'],
      'items': [],
    }, olderCloudTs);
    expect(await app.resolveCloudSnapshot(olderCloud), 'local');
    expect(app.buckets, contains('OfflineTag'));
    expect(app.buckets, isNot(contains('OldCloudTag')));

    // 2. Newer cloud snapshot while local ALSO has pending edits -> merges both non-destructively
    app.pendingCloudSync = true;
    app.lastModifiedIso = newerLocalTs.toIso8601String();
    final concurrentCloud = CloudSnapshot({
      'updatedAt': newerCloudTs.toIso8601String(),
      'buckets': ['CloudTag'],
      'items': [],
      'hist': {
        '2026-11-25': HistDay(500, [[HRow('Past Cloud Item', 150, 'CloudTag')]]).toJson(),
      },
    }, newerCloudTs);
    expect(await app.resolveCloudSnapshot(concurrentCloud), 'merged');
    expect(app.buckets, containsAll(['OfflineTag', 'CloudTag']));
    expect(app.hist['2026-11-25']!.rows.first.name, 'Past Cloud Item');

    // 3. When local has no pending edits and cloud is newer -> cloud applies cleanly
    app.pendingCloudSync = false;
    app.lastModifiedIso = olderCloudTs.toIso8601String();
    final freshCloud = CloudSnapshot({
      'updatedAt': newerCloudTs.toIso8601String(),
      'buckets': ['FreshCloudOnly'],
      'items': [],
    }, newerCloudTs);
    expect(await app.resolveCloudSnapshot(freshCloud), 'cloud');
    expect(app.buckets, ['FreshCloudOnly']);
    expect(app.syncStatus, 'synced');
  });

  testWidgets('Home empty tag card opens TagsSheet and bucket cards display per-tag budget', (WidgetTester tester) async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    await tester.pumpWidget(const SpentApp());
    await tester.pumpAndSettle();

    // Tapping empty-state card opens TagsSheet
    await tester.tap(find.text('Create your first tag'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Tag'), findsOneWidget);
    Navigator.of(tester.element(find.text('Edit Tag'))).pop();
    await tester.pumpAndSettle();

    // Bucket card shows per-tag budget cap
    app.saveTag('Food', null);
    app.saveBucketCash('Food', 500);
    app.addItem('Ramen', 250, 1, 'Food');
    app.toggle(app.items.first);
    app.go(0);
    await tester.pumpAndSettle();
    expect(find.text('of ₱500.00'), findsOneWidget);
  });

  test('Recurring bills track due status, log into today, and survive backup/restore', () async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.addBill('PLDT Fiber', 1699, 'Bills', 15);
    expect(app.dueBills.length, 1);

    // Backup/restore preserves recurring bills
    final backup = app.exportBackupJson();
    app.resetAll();
    expect(app.bills, isEmpty);
    expect(app.importBackupJson(backup), isNull);
    expect(app.bills.length, 1);

    // Logging for current month creates tag + checked item and clears due state
    app.logBillForCurrentMonth(app.bills.first);
    expect(app.dueBills, isEmpty);
    expect(app.buckets, contains('Bills'));
    expect(app.checked.any((i) => i.name == 'PLDT Fiber' && i.amt == 1699), isTrue);
  });

  testWidgets('Swipe-to-delete item supports Undo and Analytics drill-down shows items + Net balance', (WidgetTester tester) async {
    await app.setProfile(id: 'local_test', name: 'Juan');
    app.saveTag('Food', null);
    app.addItem('Sisig', 220, 1, 'Food');
    app.toggle(app.items.first);
    app.addIncome(1000, cat: 'Allowance');

    // Verify swipe-to-delete + Undo on Lists tab
    app.go(1);
    await tester.pumpWidget(const SpentApp());
    await tester.pumpAndSettle();

    await tester.drag(find.text('Sisig'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(app.items, isEmpty);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(app.items.length, 1);
    expect(app.items.first.name, 'Sisig');

    // Verify Net Balance card and Expense drill-down on Analytics tab
    app.go(3);
    await tester.pumpAndSettle();
    expect(find.text('Net'), findsOneWidget);
    expect(find.text('+₱780.00'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('See items ›'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('See items ›'));
    await tester.pumpAndSettle();
    expect(find.text('All expenses'), findsOneWidget);
    expect(find.text('Sisig'), findsOneWidget);
  });
}
