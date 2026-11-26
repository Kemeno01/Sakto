part of 'main.dart';

class Item {
  int id; String name; double price; int qty; String bucket; bool checked; List<String>? who;
  Item(this.id, this.name, this.price, this.bucket, {this.qty = 1, this.checked = false, this.who});
  double get amt => price * qty;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'qty': qty, 'bucket': bucket, 'checked': checked, 'who': who};
  factory Item.fromJson(Map<String, dynamic> j) => Item(j['id'] as int, j['name'] as String, (j['price'] as num).toDouble(), j['bucket'] as String,
      qty: j['qty'] as int, checked: j['checked'] as bool, who: (j['who'] as List?)?.cast<String>());
}

class HRow {
  String name; double amt; String bucket; double? mine; bool sp;
  HRow(this.name, this.amt, this.bucket, [this.mine, this.sp = false]);
  double get own => mine ?? amt;
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
  Map<String, double> given; Map<String, bool> changed;
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
