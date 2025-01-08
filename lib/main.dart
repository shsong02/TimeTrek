import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '/theme/time_trek_theme.dart';
import '/backend/app_state.dart';
import '/backend/firebase/firebase_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '/pages/calendar/action_calendar.dart';
import '/pages/actions/add_timeslot_calendar.dart';
import '/pages/actions/add_timeslot_event_calendar.dart';
import '/pages/actions/create_action.dart';
import '/pages/evaluation/goal_evaluation.dart';
import 'pages/chat/chat_ai_agent.dart';
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
  bool _isRailExtended = false;
  int _selectedRailIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? 'CreateGoals';
    _currentPage = widget.page;
    _selectedRailIndex = -1;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = {
      'CreateGoals': const CreateAction(),
      'ActionCalendar': const ActionCalendar(),
      'GoalEvaluation': const GoalEvaluation(),
      'chatSchedule': const ChatAIAgent(),
    };

    final currentIndex = _currentPage != null
        ? -1 // _currentPage가 있으면 bottom nav에서 선택된 항목 없음
        : tabs.keys.toList().indexOf(_currentPageName);

    return Scaffold(
      body: Row(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (details.delta.dx > 0) {
                setState(() {
                  _isRailExtended = true;
                });
              } else if (details.delta.dx < 0) {
                setState(() {
                  _isRailExtended = false;
                });
              }
            },
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: NavigationRail(
                groupAlignment: -0.85,
                extended: _isRailExtended,
                minWidth: 25,
                minExtendedWidth: 150,
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.05),
                labelType: NavigationRailLabelType.none,
                selectedIndex:
                    _selectedRailIndex < 0 ? null : _selectedRailIndex,
                useIndicator: true,
                indicatorColor: Theme.of(context).primaryColor.withOpacity(0.1),
                selectedIconTheme: IconThemeData(
                  color: Theme.of(context).primaryColor,
                  size: 28,
                  weight: 800,
                ),
                unselectedIconTheme: IconThemeData(
                  color: Theme.of(context).unselectedWidgetColor,
                  size: 24,
                ),
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedRailIndex = index;
                    if (index == 0) {
                      _currentPage = const AddTimeslotCalendar();
                      _currentPageName = 'AddTimeslotCalendar';
                    } else if (index == 1) {
                      _currentPage = const AddTimeslotEventCalendar();
                      _currentPageName = 'AddTimeslotEventCalendar';
                    }
                  });
                },
                destinations: const [
                  NavigationRailDestination(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    icon: Icon(Icons.calendar_today),
                    label: Text('타임슬롯 캘린더'),
                  ),
                  NavigationRailDestination(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    icon: Icon(Icons.event),
                    label: Text('이벤트 캘린더'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child:
                _currentPage != null ? _currentPage! : tabs[_currentPageName]!,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        onTap: (i) => setState(() {
          _currentPage = null;
          _currentPageName = tabs.keys.toList()[i];
          _selectedRailIndex = -1; // Rail 선택 초기화
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
