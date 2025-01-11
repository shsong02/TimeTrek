import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '/theme/time_trek_theme.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' if (dart.library.html) 'dart:html' as html;
import 'widgets/progress_charts.dart';
import 'widgets/execution_charts.dart';
import 'widgets/action_history.dart';
import 'widgets/email_report.dart';
import 'models/action_event_data.dart';

class GoalEvaluation extends StatefulWidget {
  const GoalEvaluation({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  final double? width;
  final double? height;

  @override
  State<GoalEvaluation> createState() => _GoalEvaluationState();
}

class _GoalEvaluationState extends State<GoalEvaluation> {
  List<ActionEventData> _actionEvents = [];
  List<ActionHistoryData> _actionHistories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 캘린더 이벤트와 액션 리스트 데이터 로드
      final calendarSnapshot =
          await FirebaseFirestore.instance.collection('calendar_event').get();

      final actionSnapshot =
          await FirebaseFirestore.instance.collection('action_list').get();

      // 액션 리스트를 맵으로 변환
      final actionMap = {
        for (var doc in actionSnapshot.docs)
          doc.data()['action_name']: doc.data()
      };

      // 액션 히스토리 로드 및 레거시 데이터 처리
      final historySnapshot =
          await FirebaseFirestore.instance.collection('action_history').get();
      // 레거시 데이터 삭제 처리
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in historySnapshot.docs) {
        final historyData = doc.data();
        if (!actionMap.containsKey(historyData['action_name'])) {
          // 레거시 데이터 삭제
          batch.delete(doc.reference);
        }
      }
      await batch.commit();

      // 데이터 병합
      final mergedData = calendarSnapshot.docs.map((doc) {
        final calendarData = doc.data();
        final actionData = actionMap[calendarData['action_name']] ?? {};
        return ActionEventData.fromMergedData(calendarData, actionData);
      }).toList();

      // 액션 이벤트 맵 생성 (action_id를 키로 사용)
      final actionEventMap = {
        for (var event in mergedData) event.actionId: event
      };

      // 액션 히스토리 데이터 병합
      final mergedHistories = historySnapshot.docs.map((doc) {
        final historyData = doc.data();
        final matchingEvent = actionEventMap[historyData['action_id']];

        // 기존 히스토리 데이터에 이벤트 데이터 병합
        if (matchingEvent != null) {
          historyData['startTime'] = matchingEvent.startTime;
          historyData['endTime'] = matchingEvent.endTime;
          historyData['timegroup'] = matchingEvent.timegroup;
          historyData['tags'] = matchingEvent.tags;
          historyData['action_status'] = matchingEvent.actionStatus;
        }

        return ActionHistoryData.fromMap(historyData);
      }).toList();

      setState(() {
        _actionEvents = mergedData;
        _actionHistories = mergedHistories;
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 로드 중 오류 발생: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: TimeTrekTheme.vitaflowBrandColor,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('일간 요약'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('주간 요약'),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('월간 요약'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                InsightDailySummaryWidget(actionEvents: _actionEvents),
                InsightWeeklySummaryWidget(
                  actionEvents: _actionEvents,
                  actionHistories: _actionHistories,
                ),
                InsightMonthlySummaryWidget(
                    actionEvents: _actionEvents,
                    actionHistories: _actionHistories),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 새로운 공통 필터 위젯 추가
class InsightFilterWidget extends StatelessWidget {
  final List<String> allTags;
  final List<String> selectedTags;
  final bool hideCompleted;
  final Function(List<String>) onTagsChanged;
  final Function(bool) onHideCompletedChanged;

  const InsightFilterWidget({
    Key? key,
    required this.allTags,
    required this.selectedTags,
    required this.hideCompleted,
    required this.onTagsChanged,
    required this.onHideCompletedChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // 태그 필터
          Wrap(
            spacing: 8.0,
            children: allTags.map((tag) {
              return FilterChip(
                label: Text(
                  tag,
                  style: TextStyle(
                    color: selectedTags.contains(tag)
                        ? Colors.white
                        : Colors.grey[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedTags.contains(tag),
                selectedColor: TimeTrekTheme.vitaflowBrandColor,
                backgroundColor: Colors.grey[200],
                checkmarkColor: Colors.white,
                onDeleted: selectedTags.contains(tag)
                    ? () {
                        final newTags = List<String>.from(selectedTags)
                          ..remove(tag);
                        onTagsChanged(newTags);
                      }
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selectedTags.contains(tag)
                        ? TimeTrekTheme.vitaflowBrandColor
                        : Colors.transparent,
                  ),
                ),
                onSelected: (selected) {
                  final newTags = List<String>.from(selectedTags);
                  if (selected) {
                    newTags.add(tag);
                  } else {
                    newTags.remove(tag);
                  }
                  onTagsChanged(newTags);
                },
              );
            }).toList(),
          ),
          // Completed 상태 토글
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                '완료된 항목 숨기기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              value: hideCompleted,
              activeColor: TimeTrekTheme.vitaflowBrandColor,
              activeTrackColor:
                  TimeTrekTheme.vitaflowBrandColor.withOpacity(0.4),
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[300],
              onChanged: onHideCompletedChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class InsightDailySummaryWidget extends StatefulWidget {
  final List<ActionEventData> actionEvents;

  const InsightDailySummaryWidget({
    Key? key,
    required this.actionEvents,
  }) : super(key: key);

  @override
  State<InsightDailySummaryWidget> createState() =>
      _InsightDailySummaryWidgetState();
}

class _InsightDailySummaryWidgetState extends State<InsightDailySummaryWidget> {
  List<String> selectedTags = [];
  bool hideCompleted = false;

  Map<String, dynamic> _getAIAnalysisDetail() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final tomorrowEnd =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);

    final todayEvents = widget.actionEvents.where(
        (e) => e.startTime.isAfter(todayStart) && e.endTime.isBefore(todayEnd));

    final tomorrowEvents = widget.actionEvents.where((e) =>
        e.startTime.isAfter(tomorrowStart) && e.endTime.isBefore(tomorrowEnd));

    final todoEvents = todayEvents.where((e) => e.actionStatus != 'completed');
    final totalExecutionTime = todoEvents.fold<num>(
        0, (sum, event) => sum + (event.actionExecutionTime ?? 0));

    return {
      'today_completed': todayEvents
          .where((e) => e.actionStatus == 'completed')
          .map((e) => e.actionName)
          .toList(),
      'today_todo': todoEvents.map((e) => e.actionName).toList(),
      'tomorrow': tomorrowEvents.map((e) => e.actionName).toList(),
      'total_execution_time': totalExecutionTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final tomorrowEnd =
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);

    // 모든 태그 추출
    final allTags =
        widget.actionEvents.expand((event) => event.tags).toSet().toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          InsightFilterWidget(
            allTags: allTags,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            onTagsChanged: (tags) => setState(() => selectedTags = tags),
            onHideCompletedChanged: (value) =>
                setState(() => hideCompleted = value),
          ),

          // 이메일 리포트 위젯 추가
          EmailReportWidget(
            reportType: 'daily',
            actionEvents: widget.actionEvents,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            startTime: todayStart,
            endTime: todayEnd,
          ),

          AIAnalysisWidget(
            type: 'daily',
            events: widget.actionEvents,
            detail: _getAIAnalysisDetail(),
            startTime: todayStart,
            endTime: todayEnd,
          ),

          // 오늘의 진행 상황
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 300,
                maxWidth: double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '오늘의 진행 상황',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  // 차트와 체크리스트
                  Card(
                    child: Column(
                      children: [
                        ProgressBarChart(
                          actionEvents: widget.actionEvents,
                          startTime: todayStart,
                          endTime: todayEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ProgressBarChartCheckList(
                          actionEvents: widget.actionEvents,
                          startTime: todayStart,
                          endTime: todayEnd,
                        ),
                      ],
                    ),
                  ),
                  // 실행 시간 차트
                  Card(
                    child: Column(
                      children: [
                        ExecutionTimePieChart(
                          actionEvents: widget.actionEvents,
                          startTime: todayStart,
                          endTime: todayEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ExecutionTimePieChartList(
                          actionEvents: widget.actionEvents,
                          startTime: todayStart,
                          endTime: todayEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 내일 예정된 항목
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 300,
                maxWidth: double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '내일 예정된 항목',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  // 동일한 위젯들을 내일 날짜로 구성
                  Card(
                    child: Column(
                      children: [
                        ProgressBarChart(
                          actionEvents: widget.actionEvents,
                          startTime: tomorrowStart,
                          endTime: tomorrowEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ProgressBarChartCheckList(
                          actionEvents: widget.actionEvents,
                          startTime: tomorrowStart,
                          endTime: tomorrowEnd,
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        ExecutionTimePieChart(
                          actionEvents: widget.actionEvents,
                          startTime: tomorrowStart,
                          endTime: tomorrowEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ExecutionTimePieChartList(
                          actionEvents: widget.actionEvents,
                          startTime: tomorrowStart,
                          endTime: tomorrowEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InsightWeeklySummaryWidget extends StatefulWidget {
  final List<ActionEventData> actionEvents;
  final List<ActionHistoryData> actionHistories;

  const InsightWeeklySummaryWidget({
    Key? key,
    required this.actionEvents,
    required this.actionHistories,
  }) : super(key: key);

  @override
  State<InsightWeeklySummaryWidget> createState() =>
      _InsightWeeklySummaryWidgetState();
}

class _InsightWeeklySummaryWidgetState
    extends State<InsightWeeklySummaryWidget> {
  List<String> selectedTags = [];
  bool hideCompleted = false;
  late PageController _pageController;
  late List<WeekRange> weekRanges;
  late int initialPage;

  @override
  void initState() {
    super.initState();
    weekRanges = _calculateMonthWeeks();
    initialPage = _findCurrentWeekIndex();
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<WeekRange> _calculateMonthWeeks() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    List<WeekRange> weeks = [];
    DateTime weekStart = firstDayOfMonth;

    while (weekStart.isBefore(lastDayOfMonth)) {
      final weekEnd = weekStart
          .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      weeks.add(WeekRange(weekStart, weekEnd));
      weekStart = weekStart.add(const Duration(days: 7));
    }

    return weeks;
  }

  int _findCurrentWeekIndex() {
    final now = DateTime.now();
    for (int i = 0; i < weekRanges.length; i++) {
      if (now.isAfter(weekRanges[i].start) && now.isBefore(weekRanges[i].end)) {
        return i;
      }
    }
    return 0;
  }

  Map<String, dynamic> _getAIAnalysisDetail() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final thisWeekEvents = widget.actionEvents.where(
        (e) => e.startTime.isAfter(weekStart) && e.endTime.isBefore(weekEnd));

    final todoEvents =
        thisWeekEvents.where((e) => e.actionStatus != 'completed');
    final totalExecutionTime = todoEvents.fold<num>(
        0, (sum, event) => sum + (event.actionExecutionTime ?? 0));

    return {
      'thisweek_completed': thisWeekEvents
          .where((e) => e.actionStatus == 'completed')
          .map((e) => e.actionName)
          .toList(),
      'thisweek_pending': thisWeekEvents
          .where((e) => e.actionStatus == 'pending')
          .map((e) => e.actionName)
          .toList(),
      'thisweek_todo': todoEvents.map((e) => e.actionName).toList(),
      'total_execution_time': totalExecutionTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final allTags =
        widget.actionEvents.expand((event) => event.tags).toSet().toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          InsightFilterWidget(
            allTags: allTags,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            onTagsChanged: (tags) => setState(() => selectedTags = tags),
            onHideCompletedChanged: (value) =>
                setState(() => hideCompleted = value),
          ),

          EmailReportWidget(
            reportType: 'weekly',
            actionEvents: widget.actionEvents,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            startTime: weekStart,
            endTime: weekEnd,
          ),

          AIAnalysisWidget(
            type: 'weekly',
            events: widget.actionEvents,
            detail: _getAIAnalysisDetail(),
            startTime: weekStart,
            endTime: weekEnd,
          ),

          // 주간 진행 상황
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 300,
                maxWidth: double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${DateFormat('MM/dd').format(weekStart)} - ${DateFormat('MM/dd').format(weekEnd)} 진행 상황',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // 차트와 체크리스트
                  Card(
                    child: Column(
                      children: [
                        ProgressBarChart(
                          actionEvents: widget.actionEvents,
                          startTime: weekStart,
                          endTime: weekEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ProgressBarChartCheckList(
                          actionEvents: widget.actionEvents,
                          startTime: weekStart,
                          endTime: weekEnd,
                        ),
                      ],
                    ),
                  ),
                  // 실행 시간 차트
                  Card(
                    child: Column(
                      children: [
                        ExecutionTimePieChart(
                          actionEvents: widget.actionEvents,
                          startTime: weekStart,
                          endTime: weekEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ExecutionTimePieChartList(
                          actionEvents: widget.actionEvents,
                          startTime: weekStart,
                          endTime: weekEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                      ],
                    ),
                  ),
                  // 액션 히스토리 타임라인
                  Card(
                    child: Column(
                      children: [
                        ActionHistoryTimeline(
                          actionHistories: widget.actionHistories,
                          startTime: weekStart,
                          endTime: weekEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        const SizedBox(height: 16),
                        ActionHistoryTimelineList(
                          actionHistories: widget.actionHistories,
                          startTime: weekStart,
                          endTime: weekEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentWeek(WeekRange week) {
    final now = DateTime.now();
    // 현재 날짜가 속한 주의 월요일을 찾음
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    // 현재 날짜가 속한 주의 일요일을 찾음
    final sunday = mondayStart.add(const Duration(days: 6));
    final sundayEnd =
        DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);

    return week.start.isAtSameMomentAs(mondayStart) &&
        week.end.isAtSameMomentAs(sundayEnd);
  }
}

// 주차 범위를 저장하는 헬퍼 클래스
class WeekRange {
  final DateTime start;
  final DateTime end;

  WeekRange(this.start, this.end);
}

class InsightMonthlySummaryWidget extends StatefulWidget {
  final List<ActionEventData> actionEvents;
  final List<ActionHistoryData> actionHistories;

  const InsightMonthlySummaryWidget({
    Key? key,
    required this.actionEvents,
    required this.actionHistories,
  }) : super(key: key);

  @override
  State<InsightMonthlySummaryWidget> createState() =>
      _InsightMonthlySummaryWidgetState();
}

class _InsightMonthlySummaryWidgetState
    extends State<InsightMonthlySummaryWidget> {
  List<String> selectedTags = [];
  bool hideCompleted = false;
  List<ActionHistoryData> _actionHistories = [];

  @override
  void initState() {
    super.initState();
    _loadActionHistories();
  }

  Future<void> _loadActionHistories() async {
    try {
      final historySnapshot =
          await FirebaseFirestore.instance.collection('action_history').get();

      setState(() {
        _actionHistories = historySnapshot.docs
            .map((doc) => ActionHistoryData.fromMap(doc.data()))
            .toList();
      });
    } catch (e) {
      print('액션 히스토리 로드 중 오류 발생: $e');
    }
  }

  Map<String, dynamic> _getAIAnalysisDetail() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final thisMonthEvents = widget.actionEvents.where(
        (e) => e.startTime.isAfter(monthStart) && e.endTime.isBefore(monthEnd));

    final todoEvents =
        thisMonthEvents.where((e) => e.actionStatus != 'completed');
    final totalExecutionTime = todoEvents.fold<num>(
        0, (sum, event) => sum + (event.actionExecutionTime ?? 0));

    return {
      'thismonth_completed': thisMonthEvents
          .where((e) => e.actionStatus == 'completed')
          .map((e) => e.actionName)
          .toList(),
      'thismonth_pending': thisMonthEvents
          .where((e) => e.actionStatus == 'pending')
          .map((e) => e.actionName)
          .toList(),
      'thismonth_todo': todoEvents.map((e) => e.actionName).toList(),
      'total_execution_time': totalExecutionTime,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // 모든 태그 추출
    final allTags =
        widget.actionEvents.expand((event) => event.tags).toSet().toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          InsightFilterWidget(
            allTags: allTags,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            onTagsChanged: (tags) => setState(() => selectedTags = tags),
            onHideCompletedChanged: (value) =>
                setState(() => hideCompleted = value),
          ),

          // 이메일 리포트 위젯 추가
          EmailReportWidget(
            reportType: 'monthly',
            actionEvents: widget.actionEvents,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            startTime: monthStart,
            endTime: monthEnd,
          ),
          // AI 분석 위젯을 필터 다음으로 이동
          AIAnalysisWidget(
            type: 'monthly',
            events: widget.actionEvents,
            detail: _getAIAnalysisDetail(),
            startTime: monthStart,
            endTime: monthEnd,
          ),

          // 월간 진행 상황
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 300,
                maxWidth: double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${DateFormat('yyyy년 MM월').format(monthStart)} 진행 상황',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // 차트와 체크리스트
                  Card(
                    child: Column(
                      children: [
                        ProgressBarChart(
                          actionEvents: widget.actionEvents,
                          startTime: monthStart,
                          endTime: monthEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ProgressBarChartCheckList(
                          actionEvents: widget.actionEvents,
                          startTime: monthStart,
                          endTime: monthEnd,
                        ),
                      ],
                    ),
                  ),
                  // 실행 시간 차트
                  Card(
                    child: Column(
                      children: [
                        ExecutionTimePieChart(
                          actionEvents: widget.actionEvents,
                          startTime: monthStart,
                          endTime: monthEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        ExecutionTimePieChartList(
                          actionEvents: widget.actionEvents,
                          startTime: monthStart,
                          endTime: monthEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                      ],
                    ),
                  ),
                  // 액션 히스토리 타임라인
                  Card(
                    child: Column(
                      children: [
                        ActionHistoryTimeline(
                          actionHistories: widget.actionHistories,
                          startTime: monthStart,
                          endTime: monthEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                        const SizedBox(height: 16),
                        ActionHistoryTimelineList(
                          actionHistories: widget.actionHistories,
                          startTime: monthStart,
                          endTime: monthEnd,
                          timegroup: '',
                          tag: selectedTags,
                          noActionStatus: hideCompleted ? ['completed'] : [],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// AI 분석 API 호출을 위한 서비스 클래스 추가
class AIAnalysisService {
  static Future<String> getAnalysis({
    required String type,
    required List<ActionEventData> events,
    required Map<String, dynamic> detail,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final url = Uri.parse(
        'https://shsong83.app.n8n.cloud/webhook-test/timetrek-goal-evaluation');
    // 'https://shsong83.app.n8n.cloud/webhook/timetrek-goal-evaluation');

    try {
      final now = DateTime.now();
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'only_email': false,
          'nowtime': now.toIso8601String(),
          'starttime': startTime.toIso8601String(),
          'endtime': endTime.toIso8601String(),
          'actionEventData': events
              .map((e) => {
                    'actionName': e.actionName,
                    'goalName': e.goalName,
                    'timegroup': e.timegroup,
                    'tags': e.tags,
                    'actionStatus': e.actionStatus,
                    'actionStatusDescription': e.actionStatusDescription,
                    'actionExecutionTime': e.actionExecutionTime,
                    'startTime': e.startTime.toIso8601String(),
                    'endTime': e.endTime.toIso8601String(),
                  })
              .toList(),
          'detail': detail,
        }),
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('AI 분석 실패: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('AI 분석 요청 중 오류 발생: $e');
    }
  }
}

// AI 분석 결과를 표시할 공통 위젯
class AIAnalysisWidget extends StatefulWidget {
  final String type;
  final List<ActionEventData> events;
  final Map<String, dynamic> detail;
  final DateTime startTime;
  final DateTime endTime;

  const AIAnalysisWidget({
    Key? key,
    required this.type,
    required this.events,
    required this.detail,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<AIAnalysisWidget> createState() => _AIAnalysisWidgetState();
}

class _AIAnalysisWidgetState extends State<AIAnalysisWidget> {
  String? _analysisResult;
  Map<String, dynamic>? _parsedAnalysis;
  bool _isLoading = false;
  DateTime? _lastAnalysisTime;

  String _getStorageKey() => 'ai_analysis_${widget.type}';

  @override
  void initState() {
    super.initState();
    _loadSavedAnalysis();
  }

  bool _isAnalysisValid(DateTime analysisTime) {
    // 현재 시간이 endtime을 넘었으면 무효
    if (DateTime.now().isAfter(widget.endTime)) {
      return false;
    }

    // 분석 유형별로 다른 유효 기간 적용
    switch (widget.type) {
      case 'daily':
        // 하루가 끝나기 전까지 유효
        return DateTime.now().isBefore(widget.endTime);

      case 'weekly':
        // 해당 주가 끝나기 전까지 유효
        return DateTime.now().isBefore(widget.endTime);

      case 'monthly':
        // 해당 월이 끝나기 전까지 유효
        return DateTime.now().isBefore(widget.endTime);

      default:
        // 기본값으로 24시간 유효
        final difference = DateTime.now().difference(analysisTime);
        return difference.inHours < 24;
    }
  }

  Future<void> _loadSavedAnalysis() async {
    try {
      final storage = html.window.localStorage;
      final key = _getStorageKey();
      final savedData = storage[key];

      if (savedData != null) {
        final data = jsonDecode(savedData);
        final analysisTime = DateTime.parse(data['timestamp']);

        if (_isAnalysisValid(analysisTime)) {
          setState(() {
            _analysisResult = data['result'];
            _parsedAnalysis = data['parsed'];
            _lastAnalysisTime = analysisTime;
          });
        } else {
          // 유효기간이 지난 데이터는 삭제
          storage.remove(key);
        }
      }
    } catch (e) {
      print('저장된 분석 결과 로드 중 오류: $e');
    }
  }

  Future<void> _saveAnalysis(String result, Map<String, dynamic> parsed) async {
    try {
      final data = {
        'result': result,
        'parsed': parsed,
        'timestamp': DateTime.now().toIso8601String(),
      };

      html.window.localStorage[_getStorageKey()] = jsonEncode(data);

      setState(() {
        _analysisResult = result;
        _parsedAnalysis = parsed;
        _lastAnalysisTime = DateTime.now();
      });
    } catch (e) {
      print('분석 결과 저장 중 오류: $e');
    }
  }

  Future<void> _getAnalysis() async {
    setState(() => _isLoading = true);
    try {
      final result = await AIAnalysisService.getAnalysis(
        type: widget.type,
        events: widget.events,
        detail: widget.detail,
        startTime: widget.startTime,
        endTime: widget.endTime,
      );

      final Map<String, dynamic> jsonResult = jsonDecode(result);
      final output = jsonResult['output'] as Map<String, dynamic>;

      String markdownContent = '';

      if (widget.type == 'daily') {
        markdownContent = '''
## 오늘의 요약
${output['today_summary']}

### 주의사항
${output['today_issue_point']}

## 내일의 계획
${output['tomorrow_summary']}

### 주의사항
${output['tomorrow_issue_point']}
''';
      } else if (widget.type == 'weekly') {
        markdownContent = '''
## 이번 주 요약
${output['thisweek_summary']}

### 지연된 작업 및 이슈
${output['thisweek_pedning_issue']}

### 완료 예상 분석
${output['thisweek_completed_estimation']}

### 목표 달성 평가
${output['thisweek_goal_evaluation']}
''';
      }

      await _saveAnalysis(markdownContent, output);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('분석 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeDisplay() {
    if (_lastAnalysisTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(_lastAnalysisTime!);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else {
      return DateFormat('MM/dd HH:mm').format(_lastAnalysisTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI 분석',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_lastAnalysisTime != null)
                      Text(
                        '마지막 분석: ${_getTimeDisplay()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _getAnalysis,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology),
                  label: Text(_isLoading ? '분석 중...' : 'AI 분석하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TimeTrekTheme.vitaflowBrandColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_analysisResult != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: MarkdownBody(
                  data: _analysisResult!,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 14, height: 1.5),
                    h1: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: TimeTrekTheme.vitaflowBrandColor,
                    ),
                    h2: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: TimeTrekTheme.vitaflowBrandColor,
                    ),
                    h3: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                    listBullet:
                        TextStyle(color: TimeTrekTheme.vitaflowBrandColor),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
