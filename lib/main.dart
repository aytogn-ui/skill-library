import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'models/skill.dart';
import 'models/routine.dart';
import 'models/routine_skill_stats.dart';
import 'providers/skill_provider.dart';
import 'providers/routine_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/skills_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/add_edit_skill_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(SkillAdapter());
  Hive.registerAdapter(RoutineAdapter());
  Hive.registerAdapter(RoutineSkillStatsAdapter());

  final skillBox = await Hive.openBox<Skill>('skills');
  final routineBox = await Hive.openBox<Routine>('routines');
  final statsBox = await Hive.openBox<RoutineSkillStats>('routine_skill_stats');

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SkillProvider()..init(skillBox),
        ),
        ChangeNotifierProvider(
          create: (_) => RoutineProvider()..init(routineBox, statsBox),
        ),
      ],
      child: const SkillLibraryApp(),
    ),
  );
}

class SkillLibraryApp extends StatelessWidget {
  const SkillLibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skill Library',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SkillsScreen(),
    RoutinesScreen(),
    ToolsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditSkillScreen()),
              ),
              backgroundColor: AppTheme.primaryPurple,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AppTheme.surfaceDark,
          selectedItemColor: AppTheme.primaryPurple,
          unselectedItemColor: AppTheme.textTertiary,
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'ホーム',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_martial_arts),
              activeIcon: Icon(Icons.sports_martial_arts),
              label: '技一覧',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.playlist_play_outlined),
              activeIcon: Icon(Icons.playlist_play),
              label: 'ルーティン',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined),
              activeIcon: Icon(Icons.track_changes),
              label: 'Tools',
            ),
          ],
        ),
      ),
    );
  }
}
