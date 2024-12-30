import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '/theme/time_trek_theme.dart';
import '/backend/app_state.dart';
import '/backend/firebase/firebase_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/pages/calendar/action_calendar.dart';
import '/pages/actions/create_action.dart';
import '/pages/evaluation/goal_evaluation.dart';
import '/pages/chat/chat_widget.dart';
import '/pages/auth/authentication_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initFirebase();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeTrek',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', ''),
        Locale('en', ''),
      ],
      theme: TimeTrekTheme.lightTheme,
      darkTheme: TimeTrekTheme.darkTheme,
      themeMode: _themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const NavBarPage(initialPage: 'CreateGoals');
          }
          return const AuthenticationWidget();
        },
      ),
    );
  }
}

class NavBarPage extends StatefulWidget {
  const NavBarPage({
    Key? key, 
    this.initialPage, 
    this.page,
  }) : super(key: key);

  final String? initialPage;
  final Widget? page;

  @override
  State<NavBarPage> createState() => _NavBarPageState();
}

class _NavBarPageState extends State<NavBarPage> {
  String _currentPageName = 'CreateGoals';
  late Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? 'CreateGoals';
    _currentPage = widget.page;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'CreateGoals': const CreateAction(),
      'ActionCalendar': const ActionCalendar(),
      'GoalEvaluation': const GoalEvaluation(),
      'chatSchedule': const ChatWidget(),
    };
    
    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);

    return Scaffold(
      body: _currentPage ?? tabs[_currentPageName],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => setState(() {
          _currentPage = null;
          _currentPageName = tabs.keys.toList()[i];
        }),
        backgroundColor: const Color(0xFFC5D7F7),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).textTheme.bodyLarge?.color,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.tour_outlined, size: 24.0),
            label: '목표',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.today, size: 24.0),
            activeIcon: Icon(Icons.today, size: 24.0),
            label: '할일',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined, size: 24.0),
            label: '평가',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '채팅',
          )
        ],
      ),
    );
  }
}
