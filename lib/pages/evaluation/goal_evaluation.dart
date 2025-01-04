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


// 데이터 모델
class ActionEventData {
  final String actionId;
  final String actionName;
  final String goalName;
  final String timegroup;
  final List<String> tags;
  final String actionStatus;
  final String? actionStatusDescription;
  final double actionExecutionTime;
  final DateTime startTime;
  final DateTime endTime;
  final String? attachedImage;
  final String? attachedFile;

  ActionEventData({
    required this.actionId,
    required this.actionName,
    required this.goalName,
    required this.timegroup,
    required this.tags,
    required this.actionStatus,
    this.actionStatusDescription,
    required this.actionExecutionTime,
    required this.startTime,
    required this.endTime,
    this.attachedImage,
    this.attachedFile,
  });

  factory ActionEventData.fromMergedData(
      Map<String, dynamic> calendarEvent, Map<String, dynamic> actionList) {
    return ActionEventData(
      actionId: actionList['id'] ?? calendarEvent['action_id'] ?? '',
      actionName: actionList['action_name'] ?? calendarEvent['action_name'] ?? '',
      goalName: actionList['goal_name'] ?? calendarEvent['goal_name'] ?? '',
      timegroup: actionList['timegroup'] ?? calendarEvent['timegroup'] ?? '',
      tags: List<String>.from(calendarEvent['goal_tag'] ?? []),
      actionStatus: actionList['action_status'] ?? calendarEvent['action_status'] ?? '',
      actionStatusDescription: calendarEvent['action_status_description'],
      actionExecutionTime: (actionList['action_execution_time'] ?? calendarEvent['action_execution_time'] ?? 0).toDouble(),
      startTime: (calendarEvent['startTime'] as Timestamp).toDate(),
      endTime: (calendarEvent['endTime'] as Timestamp).toDate(),
      attachedImage: calendarEvent['attached_image'],
      attachedFile: calendarEvent['attached_file'],
    );
  }
}


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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 캘린 이벤트와 액션 리스트 데이터 로드
      final calendarSnapshot = await FirebaseFirestore.instance
          .collection('calendar_event')
          .get();
      
      final actionSnapshot = await FirebaseFirestore.instance
          .collection('action_list')
          .get();

      // 액션 리스트를 맵으로 변환하여 빠른 조회 가능하게 함
      final actionMap = {
        for (var doc in actionSnapshot.docs)
          doc.data()['action_name']: doc.data()
      };

      // 데이터 병합
      final mergedData = calendarSnapshot.docs.map((doc) {
        final calendarData = doc.data();
        final actionData = actionMap[calendarData['action_name']] ?? {};
        return ActionEventData.fromMergedData(calendarData, actionData);
      }).toList();

      setState(() {
        _actionEvents = mergedData;
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
                InsightWeeklySummaryWidget(actionEvents: _actionEvents),
                InsightMonthlySummaryWidget(actionEvents: _actionEvents),
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
                    color: selectedTags.contains(tag) ? Colors.white : Colors.grey[800],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: selectedTags.contains(tag),
                selectedColor: TimeTrekTheme.vitaflowBrandColor,
                backgroundColor: Colors.grey[200],
                checkmarkColor: Colors.white,
                onDeleted: selectedTags.contains(tag) ? () {
                  final newTags = List<String>.from(selectedTags)..remove(tag);
                  onTagsChanged(newTags);
                } : null,
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
              activeTrackColor: TimeTrekTheme.vitaflowBrandColor.withOpacity(0.4),
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
  State<InsightDailySummaryWidget> createState() => _InsightDailySummaryWidgetState();
}

class _InsightDailySummaryWidgetState extends State<InsightDailySummaryWidget> {
  List<String> selectedTags = [];
  bool hideCompleted = false;

  Map<String, List<String>> _getAIAnalysisDetail() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final tomorrowEnd = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);

    final todayEvents = widget.actionEvents.where((e) => 
      e.startTime.isAfter(todayStart) && e.endTime.isBefore(todayEnd));
    
    final tomorrowEvents = widget.actionEvents.where((e) => 
      e.startTime.isAfter(tomorrowStart) && e.endTime.isBefore(tomorrowEnd));

    return {
      'today_completed': todayEvents
          .where((e) => e.actionStatus == 'completed')
          .map((e) => e.actionName)
          .toList(),
      'today_todo': todayEvents
          .where((e) => e.actionStatus != 'completed')
          .map((e) => e.actionName)
          .toList(),
      'tomorrow': tomorrowEvents
          .map((e) => e.actionName)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowStart = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    final tomorrowEnd = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59, 59);

    // 모든 태그 추출
    final allTags = widget.actionEvents
        .expand((event) => event.tags)
        .toSet()
        .toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          InsightFilterWidget(
            allTags: allTags,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            onTagsChanged: (tags) => setState(() => selectedTags = tags),
            onHideCompletedChanged: (value) => setState(() => hideCompleted = value),
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
          ),

          // 오늘의 진행 상황
          Card(
            margin: const EdgeInsets.all(8.0),
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

          // 내일 예정된 항목
          Card(
            margin: const EdgeInsets.all(8.0),
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
        ],
      ),
    );
  }
}

class InsightWeeklySummaryWidget extends StatefulWidget {
  final List<ActionEventData> actionEvents;

  const InsightWeeklySummaryWidget({
    Key? key,
    required this.actionEvents,
  }) : super(key: key);

  @override
  State<InsightWeeklySummaryWidget> createState() => _InsightWeeklySummaryWidgetState();
}

class _InsightWeeklySummaryWidgetState extends State<InsightWeeklySummaryWidget> {
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
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
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

  Map<String, List<String>> _getAIAnalysisDetail() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final thisWeekEvents = widget.actionEvents.where((e) => 
      e.startTime.isAfter(weekStart) && e.endTime.isBefore(weekEnd));

    return {
      'thisweek_completed': thisWeekEvents
          .where((e) => e.actionStatus == 'completed')
          .map((e) => e.actionName)
          .toList(),
      'thisweek_todo': thisWeekEvents
          .where((e) => e.actionStatus != 'completed')
          .map((e) => e.actionName)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final allTags = widget.actionEvents
        .expand((event) => event.tags)
        .toSet()
        .toList();

    return Column(
      children: [
        InsightFilterWidget(
          allTags: allTags,
          selectedTags: selectedTags,
          hideCompleted: hideCompleted,
          onTagsChanged: (tags) => setState(() => selectedTags = tags),
          onHideCompletedChanged: (value) => setState(() => hideCompleted = value),
        ),
        
        // AI 분석 위젯을 필터 다음으로 이동
        AIAnalysisWidget(
          type: 'weekly',
          events: widget.actionEvents,
          detail: _getAIAnalysisDetail(),
        ),
        
        // 주간 캐러셀
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: weekRanges.length,
            onPageChanged: (index) {
              setState(() {});
            },
            itemBuilder: (context, index) {
              final week = weekRanges[index];
              final isCurrentWeek = index == initialPage;
              
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: isCurrentWeek ? BoxDecoration(
                        color: TimeTrekTheme.vitaflowBrandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ) : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${DateFormat('MM/dd').format(week.start)} - ${DateFormat('MM/dd').format(week.end)}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: isCurrentWeek ? FontWeight.bold : null,
                              color: isCurrentWeek ? TimeTrekTheme.vitaflowBrandColor : null,
                            ),
                          ),
                          if (isCurrentWeek) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: TimeTrekTheme.vitaflowBrandColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '이번 주',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '진행 상황',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ProgressBarChart(
                            actionEvents: widget.actionEvents,
                            startTime: week.start,
                            endTime: week.end,
                            timegroup: '',
                            tag: selectedTags,
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                          ProgressBarChartCheckList(
                            actionEvents: widget.actionEvents,
                            startTime: week.start,
                            endTime: week.end,
                          ),
                        ],
                      ),
                    ),

                    // 실행 시간 분석
                    Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '실행 시간 분석',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ExecutionTimePieChart(
                            actionEvents: widget.actionEvents,
                            startTime: week.start,
                            endTime: week.end,
                            timegroup: '',
                            tag: selectedTags,
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                          ExecutionTimePieChartList(
                            actionEvents: widget.actionEvents,
                            startTime: week.start,
                            endTime: week.end,
                            timegroup: '',
                            tag: selectedTags,
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                        ],
                      ),
                    ),

                    // 액션 히스토리
                    Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              '액션 히스토리',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ActionHistoryTimeline(
                            actionEvents: widget.actionEvents,
                            startTime: week.start,
                            endTime: week.end,
                            timegroup: '',
                            tag: selectedTags,
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                          ActionHistoryTimelineList(
                            actionEvents: widget.actionEvents,
                            startTime: week.start,
                            endTime: week.end,
                            timegroup: '',
                            tag: selectedTags,
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
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

  const InsightMonthlySummaryWidget({
    Key? key,
    required this.actionEvents,
  }) : super(key: key);

  @override
  State<InsightMonthlySummaryWidget> createState() => _InsightMonthlySummaryWidgetState();
}

class _InsightMonthlySummaryWidgetState extends State<InsightMonthlySummaryWidget> {
  List<String> selectedTags = [];
  bool hideCompleted = false;

  Map<String, List<String>> _getAIAnalysisDetail() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final thisMonthEvents = widget.actionEvents.where((e) => 
      e.startTime.isAfter(monthStart) && e.endTime.isBefore(monthEnd));

    return {
      'thismonth_completed': thisMonthEvents
          .where((e) => e.actionStatus == 'completed')
          .map((e) => e.actionName)
          .toList(),
      'thismonth_todo': thisMonthEvents
          .where((e) => e.actionStatus != 'completed')
          .map((e) => e.actionName)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // 모든 태그 추출
    final allTags = widget.actionEvents
        .expand((event) => event.tags)
        .toSet()
        .toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          InsightFilterWidget(
            allTags: allTags,
            selectedTags: selectedTags,
            hideCompleted: hideCompleted,
            onTagsChanged: (tags) => setState(() => selectedTags = tags),
            onHideCompletedChanged: (value) => setState(() => hideCompleted = value),
          ),
          
          // AI 분석 위젯을 필터 다음으로 이동
          AIAnalysisWidget(
            type: 'monthly',
            events: widget.actionEvents,
            detail: _getAIAnalysisDetail(),
          ),
          
          // 월간 진행 상황
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${DateFormat('yyyy년 MM월').format(monthStart)} 진행 상황',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                        actionEvents: widget.actionEvents,
                        startTime: monthStart,
                        endTime: monthEnd,
                        timegroup: '',
                        tag: selectedTags,
                        noActionStatus: hideCompleted ? ['completed'] : [],
                      ),
                      ActionHistoryTimelineList(
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
              ],
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
    required Map<String, List<String>> detail,
  }) async {
    final url = Uri.parse('https://shsong83.app.n8n.cloud/webhook/timetrek-goal-evaluation');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'actionEventData': events.map((e) => {
            'actionName': e.actionName,
            'goalName': e.goalName,
            'timegroup': e.timegroup,
            'tags': e.tags,
            'actionStatus': e.actionStatus,
            'actionStatusDescription': e.actionStatusDescription,
            'actionExecutionTime': e.actionExecutionTime,
            'startTime': e.startTime.toIso8601String(),
            'endTime': e.endTime.toIso8601String(),
          }).toList(),
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
  final Map<String, List<String>> detail;

  const AIAnalysisWidget({
    Key? key,
    required this.type,
    required this.events,
    required this.detail,
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
    final now = DateTime.now();
    final difference = now.difference(analysisTime);
    // 24시간 이내의 분석 결과만 유효
    return difference.inHours < 24;
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
                    listBullet: TextStyle(color: TimeTrekTheme.vitaflowBrandColor),
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

// 이메일 전송 위젯 추가
class EmailReportWidget extends StatefulWidget {
  final String reportType; // 'daily', 'weekly', 'monthly'
  final List<ActionEventData> actionEvents;
  final List<String> selectedTags;
  final bool hideCompleted;
  final DateTime startTime;
  final DateTime endTime;

  const EmailReportWidget({
    Key? key,
    required this.reportType,
    required this.actionEvents,
    required this.selectedTags,
    required this.hideCompleted,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<EmailReportWidget> createState() => _EmailReportWidgetState();
}

class _EmailReportWidgetState extends State<EmailReportWidget> {
  final _emailController = TextEditingController();
  bool _isSending = false;
  bool _isExpanded = false;
  String? _analysisResult;

  String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  Future<void> _sendEmail() async {
    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효한 이메일 주소를 입력해주세요')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      print('이메일 리포트 생성 시작...');
      final htmlContent = await _generateHtmlReport();
      
      if (htmlContent == null) {
        print('HTML 리포트 생성 실패');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('리포트 생성 중 오류가 발생했습니다')),
          );
        }
        return;
      }
      
      print('HTML 리포트 생성 완료, API 호출 시작...');
      final url = Uri.parse('https://shsong83.app.n8n.cloud/webhook/timetrek-goal-evaluation-send-email');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': _emailController.text,
          'subject': '${widget.reportType == 'daily' ? '[TimeTrek] 일간' : 
                     widget.reportType == 'weekly' ? '[TimeTrek] 주간' : '[TimeTrek] 월간'} 목표 평가 리포트',
          'html': htmlContent,
        }),
      );

      print('API 응답 상태 코드: ${response.statusCode}');
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('리포트가 이메일로 전송되었습니다')),
          );
        }
      } else {
        print('API 오류 응답: ${response.body}');
        throw Exception('이메일 전송 실패');
      }
    } catch (e) {
      print('이메일 전송 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이메일 전송 중 오류가 발생했습니다')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<String?> _generateHtmlReport() async {
    try {
      // 데이터 준비
      final filteredEvents = widget.actionEvents.where((e) => 
        e.startTime.isAfter(widget.startTime) &&
        e.endTime.isBefore(widget.endTime) &&
        (widget.selectedTags.isEmpty || widget.selectedTags.any((tag) => e.tags.contains(tag))) &&
        (!widget.hideCompleted || e.actionStatus != 'completed')
      ).toList();

      // 시간대별 데이터 계산
      final timeGroups = <String, double>{};
      for (var event in filteredEvents) {
        final hours = event.actionExecutionTime / 60.0; // 분을 시간으로 변환
        timeGroups[event.timegroup] = (timeGroups[event.timegroup] ?? 0) + hours;
      }

      // 진행률 계산
      final completedCount = filteredEvents.where((e) => e.actionStatus == 'completed').length;
      final totalCount = filteredEvents.length;
      final progress = totalCount > 0 ? (completedCount / totalCount * 100) : 0;

      print('데이터 준비 완료: ${filteredEvents.length}개 이벤트, ${timeGroups.length}개 시간대');

      // AI 분석 결과 가져오기
      String aiAnalysis = '';
      try {
        // 로컬 스토리지에서 AI 분석 결과 가져오기
        final storageKey = 'ai_analysis_${widget.reportType}';
        final savedData = html.window.localStorage[storageKey];
        
        if (savedData != null) {
          final data = jsonDecode(savedData);
          final output = data['parsed'] as Map<String, dynamic>;
          
          if (widget.reportType == 'daily') {
            aiAnalysis = '''
              <div class="card">
                <h2 class="section-title">AI 분석</h2>
                <div class="ai-analysis">
                  <h3>오늘의 요약</h3>
                  <p>${escapeHtml(output['today_summary'] ?? '')}</p>
                  
                  <h3>주의사항</h3>
                  <p>${escapeHtml(output['today_issue_point'] ?? '')}</p>
                  
                  <h3>내일의 계획</h3>
                  <p>${escapeHtml(output['tomorrow_summary'] ?? '')}</p>
                  
                  <h3>주의사항</h3>
                  <p>${escapeHtml(output['tomorrow_issue_point'] ?? '')}</p>
                </div>
              </div>
            ''';
          }
        } else {
          aiAnalysis = '''
            <div class="card">
              <h2 class="section-title">AI 분석</h2>
              <p style="color: #666;">AI 분석 결과가 없습니다. AI 분석을 먼저 실행해주세요.</p>
            </div>
          ''';
        }
      } catch (e) {
        print('저장된 AI 분석 결과 가져오기 실패: $e');
        aiAnalysis = '''
          <div class="card">
            <h2 class="section-title">AI 분석</h2>
            <p style="color: #666;">저장된 AI 분석 결과를 가져오는 중 오류가 발생했습니다.</p>
          </div>
        ''';
      }

      final reportHtml = '''
        <!DOCTYPE html>
        <html lang="ko">
        <head>
          <meta charset="UTF-8">
          <title>${widget.reportType == 'daily' ? '일간' : widget.reportType == 'weekly' ? '주간' : '월간'} 목표 평가 리포트</title>
          <style>
            body { 
              font-family: -apple-system, BlinkMacSystemFont, sans-serif; 
              line-height: 1.6; 
              color: #333; 
              margin: 0;
              padding: 20px;
              background-color: #f5f5f5;
            }
            .container {
              max-width: 800px;
              margin: 0 auto;
            }
            .card {
              background: #fff;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              margin-bottom: 20px;
              padding: 20px;
            }
            .section-title {
              color: #333;
              border-bottom: 2px solid #eee;
              padding-bottom: 10px;
              margin-bottom: 20px;
            }
            .progress-container {
              margin: 20px 0;
            }
            .progress-bar {
              background: #e0e0e0;
              border-radius: 4px;
              height: 20px;
              overflow: hidden;
            }
            .progress-fill {
              background: #4CAF50;
              height: 100%;
              transition: width 0.3s ease;
            }
            .stats-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
              gap: 20px;
              margin: 20px 0;
            }
            .stat-card {
              background: #f8f9fa;
              padding: 15px;
              border-radius: 8px;
              text-align: center;
            }
            .ai-analysis h3 {
              color: #2196F3;
              margin-top: 20px;
              margin-bottom: 10px;
            }
            .ai-analysis p {
              color: #666;
              margin-bottom: 15px;
              line-height: 1.6;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1 style="text-align: center; color: #2196F3;">일일 목표 평가 리포트</h1>
            
            <!-- AI 분석 결과 추가 -->
            $aiAnalysis
            
            <div class="card">
              <h2 class="section-title">시간대별 실행 시간</h2>
              <div style="display: flex; justify-content: space-between; margin-bottom: 20px;">
                <div style="flex: 1;">
                  <table style="width: 100%; border-collapse: collapse;">
                    <tr style="background-color: #f5f5f5;">
                      <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">시간</th>
                      <th style="padding: 12px; text-align: left; border: 1px solid #ddd;">업무</th>
                    </tr>
                    ${([...filteredEvents]
                      ..sort((a, b) => a.startTime.compareTo(b.startTime)))
                      .map((e) => '''
                        <tr>
                          <td style="padding: 12px; border: 1px solid #ddd;">
                            ${DateFormat('HH:mm').format(e.startTime)} - ${DateFormat('HH:mm').format(e.endTime)}
                          </td>
                          <td style="padding: 12px; border: 1px solid #ddd;">${escapeHtml(e.actionName)}</td>
                        </tr>
                      ''').join('')}
                  </table>
                </div>
              </div>
            </div>

            <div class="card">
              <h2 class="section-title">진행 상황 요약</h2>
              <div class="progress-container">
                <div class="progress-bar">
                  <div class="progress-fill" style="width: ${progress}%"></div>
                </div>
                <p style="text-align: center;">
                  전체 진행률: ${progress.toStringAsFixed(1)}% (${completedCount}/${totalCount})
                </p>
              </div>
              
              <div class="stats-grid">
                <div class="stat-card">
                  <h3>전체 액션</h3>
                  <p style="font-size: 24px; font-weight: bold;">${totalCount}개</p>
                </div>
                <div class="stat-card">
                  <h3>완료된 액션</h3>
                  <p style="font-size: 24px; font-weight: bold;">${completedCount}개</p>
                </div>
              </div>
            </div>

            <div class="card">
              <h2 class="section-title">액션 목록</h2>
              <div style="max-height: 500px; overflow-y: auto;">
                ${filteredEvents.map((e) => '''
                  <div style="padding: 12px; border-bottom: 1px solid #eee; display: flex; align-items: center;">
                    <span style="margin-right: 12px; font-size: 20px;">
                      ${e.actionStatus == 'completed' ? '✅' : '⬜️'}
                    </span>
                    <div>
                      <strong>${escapeHtml(e.actionName)}</strong>
                      <br>
                      <small style="color: #666;">
                        ${escapeHtml(e.goalName)}
                        ${e.tags.isNotEmpty ? '<br>태그: ${escapeHtml(e.tags.join(", "))}' : ''}
                      </small>
                    </div>
                  </div>
                ''').join('')}
              </div>
            </div>
          </div>
        </body>
        </html>
      ''';

      print('HTML 리포트 생성 완료: ${reportHtml.length} 바이트');
      return reportHtml;
    } catch (e) {
      print('HTML 리포트 생성 중 오류: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: ExpansionTile(
        title: const Text(
          '📧 리포트 이메일로 받기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40, // 버튼 높이와 동일하게 설정
                    child: TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        hintText: '이메일 주소 입력',
                        hintStyle: TextStyle(fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendEmail,
                    icon: _isSending 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: Text(
                      _isSending ? '전송 중...' : '전송하기',
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TimeTrekTheme.vitaflowBrandColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
