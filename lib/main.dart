import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_config.dart';
import 'supabase_config.dart';

part 'theme.dart';
part 'models.dart';
part 'app_state.dart';
part 'auth.dart';
part 'drawer.dart';
part 'home_tab.dart';
part 'lists_tab.dart';
part 'split_tab.dart';
part 'analytics_tab.dart';
part 'scanner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  await initAuth();
  runApp(const SpentApp());
}

final shellKey = GlobalKey<ScaffoldState>();

class SpentApp extends StatefulWidget {
  const SpentApp({super.key});
  @override
  State<SpentApp> createState() => _SpentAppState();
}

class _SpentAppState extends State<SpentApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) app.checkRollover();
  }
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (_, _) {
        final br = isDark ? Brightness.dark : Brightness.light;
        final base = ThemeData(useMaterial3: true, brightness: br);
        return MaterialApp(
            title: 'Sakto', debugShowCheckedModeBanner: false, navigatorKey: navKey,
            theme: base.copyWith(
                colorScheme: ColorScheme.fromSeed(seedColor: kPr, brightness: br),
                scaffoldBackgroundColor: kBg,
                textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
                popupMenuTheme: PopupMenuThemeData(color: kCard),
                dialogTheme: DialogThemeData(backgroundColor: kCard),
                bottomSheetTheme: BottomSheetThemeData(backgroundColor: kCard)),
            home: const AuthGate());
      });
}

class Shell extends StatelessWidget {
  const Shell({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: app,
      builder: (c, _) {
        shellCtx = c;
        const pages = [HomePage(), ListsPage(), SplitPage(), StatsPage()];
        Widget nav(int i, IconData ic, String t) => Expanded(
            child: InkWell(onTap: () => app.go(i),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(ic, color: app.tab == i ? kInk : kMut), Text(t, style: ts(10, w: app.tab == i ? w7 : FontWeight.w500, c: app.tab == i ? kInk : kMut)),
                ])));
        return Scaffold(
            key: shellKey, drawer: const ProfileDrawer(),
            body: pages[app.tab],
            floatingActionButton: FloatingActionButton(
                onPressed: () => showSheet(c, const AddChoiceSheet()),
                backgroundColor: kLil, foregroundColor: Colors.white, shape: const CircleBorder(), child: const Icon(Icons.add, size: 32)),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
                color: kCard, shape: const CircularNotchedRectangle(), notchMargin: 8, height: 64, padding: EdgeInsets.zero,
                child: Row(children: [
                  nav(0, Icons.home_rounded, 'Home'), nav(1, Icons.format_list_bulleted_rounded, 'Lists'),
                  const SizedBox(width: 76),
                  nav(2, Icons.donut_large_rounded, 'Split'), nav(3, Icons.bar_chart_rounded, 'Analytics'),
                ])));
      });
}
