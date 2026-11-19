import 'package:flutter/material.dart';
import 'data/farm_store.dart';
import 'screens/animals_page.dart';
import 'screens/calculator_page.dart';
import 'screens/feeds_page.dart';
import 'screens/history_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = await FarmStore.open();
    runApp(MazraatiApp(store: store));
  } catch (error) {
    runApp(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('مزرعتي — خطأ في قاعدة البيانات')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('لم يمكن فتح قاعدة البيانات المحلية. لم يتم حذف بياناتك.\n' + error.toString()),
          ),
        ),
      ),
    ));
  }
}

class MazraatiApp extends StatelessWidget {
  const MazraatiApp({super.key, required this.store});
  final FarmStore store;

  @override
  Widget build(BuildContext context) {
    final light = ColorScheme.fromSeed(
      seedColor: const Color(0xff27634c),
      brightness: Brightness.light,
    );
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xff75b99b),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مزرعتي',
      theme: ThemeData(useMaterial3: true, colorScheme: light),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: dark),
      themeMode: ThemeMode.system,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: FarmHome(store: store),
      ),
    );
  }
}

class FarmHome extends StatefulWidget {
  const FarmHome({super.key, required this.store});
  final FarmStore store;

  @override
  State<FarmHome> createState() => _FarmHomeState();
}

class _FarmHomeState extends State<FarmHome> {
  int current = 0;
  int reload = 0;

  @override
  Widget build(BuildContext context) {
    final views = <Widget>[
      AnimalsPage(key: ValueKey('animals' + reload.toString()), store: widget.store),
      FeedsPage(key: ValueKey('feeds' + reload.toString()), store: widget.store),
      CalculatorPage(key: ValueKey('calculator' + reload.toString()), store: widget.store),
      HistoryPage(key: ValueKey('history' + reload.toString()), store: widget.store),
    ];
    const names = ['الحيوانات', 'الأعلاف', 'الحاسبة', 'السجل'];
    return Scaffold(
      appBar: AppBar(
        title: Text('مزرعتي | ' + names[current]),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(() => reload++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: views[current]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (v) => setState(() {
          current = v;
          reload++;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets), label: 'الحيوانات'),
          NavigationDestination(icon: Icon(Icons.grass), label: 'الأعلاف'),
          NavigationDestination(icon: Icon(Icons.calculate), label: 'الحاسبة'),
          NavigationDestination(icon: Icon(Icons.history), label: 'السجل'),
        ],
      ),
    );
  }
}
