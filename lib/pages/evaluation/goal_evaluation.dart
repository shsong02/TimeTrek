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
          
          // AI 분석 위젯을 필터 다음으로 이동
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

class ProgressBarChart extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ProgressBarChart({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    // 시간 간격 계산 수정
    final totalDuration = endTime.difference(startTime);
    final isWithinDay = totalDuration.inHours <= 24;
    final intervalDuration = isWithinDay 
        ? const Duration(hours: 2)  // 2시간 단위
        : totalDuration.inDays <= 7 
            ? const Duration(days: 1)  // 1일 단위
            : const Duration(days: 2);  // 2일 단위

    // 전체 구간 수 계산 수정
    final totalIntervals = isWithinDay
        ? 12  // 24시간을 2시간 간격으로 나누면 12개 구간
        : totalDuration.inDays <= 7
            ? totalDuration.inDays + 1
            : (totalDuration.inDays / 2).ceil();

    // 모든 구간에 대해 기본값 0으로 초기화
    final Map<int, double> scheduledTimeByPeriod = {
      for (var i = 0; i < totalIntervals; i++) i: 0
    };
    final Map<int, double> completedTimeByPeriod = {
      for (var i = 0; i < totalIntervals; i++) i: 0
    };
    final Map<int, List<ActionEventData>> eventsByPeriod = {};

    // 필터링된 이벤트에 대한 시간 계산
    final filteredEvents = actionEvents.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList();

    // 이벤트 시간 계산 및 할당 수정
    for (var event in filteredEvents) {
      var currentTime = event.startTime;
      while (currentTime.isBefore(event.endTime)) {
        final periodIndex = isWithinDay
            ? currentTime.hour ~/ 2  // 2시간 단위로 인덱스 계산
            : totalDuration.inDays <= 7
                ? currentTime.difference(startTime).inDays
                : currentTime.difference(startTime).inDays ~/ 2;

        // 이벤트 목록 저장
        eventsByPeriod.putIfAbsent(periodIndex, () => []).add(event);

        // 실행 시간 계산 (구간에 걸쳐있는 시간만큼 분배)
        final periodEnd = currentTime.add(intervalDuration);
        final eventEndInPeriod = event.endTime.isBefore(periodEnd) 
            ? event.endTime 
            : periodEnd;
        final durationInPeriod = eventEndInPeriod.difference(currentTime).inMinutes;
        final totalDurationMinutes = event.endTime.difference(event.startTime).inMinutes;
        final ratio = durationInPeriod / totalDurationMinutes;
        final timeInPeriod = event.actionExecutionTime * ratio;

        // 예정된 시간 업데이트
        scheduledTimeByPeriod.update(
          periodIndex,
          (value) => value + timeInPeriod,
          ifAbsent: () => timeInPeriod,
        );

        // 완료된 시간 업데이트
        if (event.actionStatus == 'completed') {
          completedTimeByPeriod.update(
            periodIndex,
            (value) => value + timeInPeriod,
            ifAbsent: () => timeInPeriod,
          );
        }

        currentTime = periodEnd;
      }
    }

    return Column(
      children: [
        // 범례 추가
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('예상 실행 시간', TimeTrekTheme.vitaflowBrandColor),
              const SizedBox(width: 16),
              _buildLegendItem('실제 실행 시간', TimeTrekTheme.proudMomentColor),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: AspectRatio(
            aspectRatio: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: scheduledTimeByPeriod.isEmpty ? 10 : 
                        scheduledTimeByPeriod.values.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final periodEvents = eventsByPeriod[group.x.toInt()] ?? [];
                        if (periodEvents.isEmpty) return null;

                        final tooltipText = rodIndex == 0 
                            ? '예정된 액션:\n' 
                            : '완료된 액션:\n';
                        
                        final displayEvents = periodEvents.take(4).toList();
                        final remainingCount = periodEvents.length - displayEvents.length;
                        
                        final tooltipContent = tooltipText + displayEvents
                            .map((e) => '${e.actionName} (${e.actionExecutionTime}h)')
                            .join('\n') +
                            (remainingCount > 0 ? '\n외 $remainingCount개' : '');
                        
                        return BarTooltipItem(
                          tooltipContent,
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (isWithinDay) {
                            final hour = startTime.add(Duration(hours: value.toInt() * 2)).hour;
                            if (hour % 4 != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '$hour시',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          } else if (totalDuration.inDays <= 7) {
                            final date = startTime.add(Duration(days: value.toInt()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('E').format(date),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          } else {
                            final date = startTime.add(Duration(days: value.toInt() * 2));
                            if (date.day % 5 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${date.day}일',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max) return const SizedBox.shrink();
                          
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              value.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.white10,
                        strokeWidth: 0.5,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.white10,
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.white24),
                  ),
                  barGroups: List.generate(totalIntervals, (index) {
                    final scheduledTime = scheduledTimeByPeriod[index] ?? 0;
                    final completedTime = completedTimeByPeriod[index] ?? 0;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        // 예상 실행 시간 막대 (뒤에 배치)
                        BarChartRodData(
                          toY: scheduledTime,
                          color: TimeTrekTheme.vitaflowBrandColor.withOpacity(0.3),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        // 실제 실행 시간 막대 (앞에 배치)
                        BarChartRodData(
                          toY: completedTime,
                          color: TimeTrekTheme.proudMomentColor.withOpacity(0.8),
                          width: 12, // 약간 더 좁게 만들어서 뒤의 막대가 보이도록 함
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class ProgressBarChartCheckList extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;

  const ProgressBarChartCheckList({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 시간 범위 내의 액션들을 필터링
    final filteredActions = actionEvents.where((event) {
      return event.startTime.isAfter(startTime) && 
             event.endTime.isBefore(endTime);
    }).toList();

    // 목표별로 그룹화
    final groupedByGoal = <String, List<ActionEventData>>{};
    for (var action in filteredActions) {
      groupedByGoal.putIfAbsent(action.goalName, () => []).add(action);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedByGoal.length,
      itemBuilder: (context, index) {
        final goalName = groupedByGoal.keys.elementAt(index);
        final actions = groupedByGoal[goalName]!;
        
        return ExpansionTile(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  goalName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${actions.length}개 액션)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              itemBuilder: (context, actionIndex) {
                final action = actions[actionIndex];
                final progress = action.actionStatus == 'completed' ? 1.0 : 0.0;
                
                return ListTile(
                  title: Text(action.actionName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress == 1.0 ? Colors.green : Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '상태: ${action.actionStatus} • 예상 시간: ${action.actionExecutionTime}시간',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Icon(
                    action.actionStatus == 'completed' 
                        ? Icons.check_circle 
                        : Icons.pending,
                    color: action.actionStatus == 'completed'
                        ? Colors.green
                        : Colors.grey,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ExecutionTimePieChart extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ExecutionTimePieChart({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 필터링된 이벤트 목록
    final filteredEvents = actionEvents.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList();

    // 액션별 실행 시간 합계 계산
    final actionTimes = <String, double>{};
    for (var event in filteredEvents) {
      actionTimes.update(
        event.actionName,
        (value) => value + event.actionExecutionTime,
        ifAbsent: () => event.actionExecutionTime,
      );
    }

    // 색상 리스트를 20개로 확장
    final colors = [
      TimeTrekTheme.vitaflowBrandColor,
      TimeTrekTheme.successColor,
      TimeTrekTheme.alertColor,
      TimeTrekTheme.proudMomentColor,
      const Color(0xFF845EC2), // 보라색
      const Color(0xFFD65DB1), // 분홍색
      const Color(0xFF4B4453), // 진회색
      const Color(0xFFFF9671), // 연한 주황색
      const Color(0xFFFFC75F), // 밝은 노란색
      const Color(0xFF008F7A), // 청록색
      const Color(0xFF0089BA), // 하늘색
      const Color(0xFFC34A36), // 붉은 갈색
      const Color(0xFF5B8C5A), // 초록색
      const Color(0xFFBC6C25), // 갈색
      const Color(0xFF6B4E71), // 자주색
      const Color(0xFF2D6A4F), // 진초록색
      const Color(0xFF9B2226), // 와인색
      const Color(0xFF48BFE3), // 밝은 파랑
      const Color(0xFF774936), // 다크 브라운
      const Color(0xFF6930C3), // 진보라색
    ];

    // 파이 차트 섹션 데이터 생성
    final sections = actionTimes.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final actionTime = entry.value;
      final color = colors[index % colors.length];
      
      return PieChartSectionData(
        value: actionTime.value,
        title: '${index + 1}',
        color: color,
        radius: 80,
        titleStyle: Theme.of(context).textTheme.titleSmall,
      );
    }).toList();

    // 총 시간 계산
    double totalTime = actionTimes.values.fold(0, (sum, time) => sum + time);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AspectRatio(
          aspectRatio: 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '총 시간',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${totalTime.toStringAsFixed(1)}h',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExecutionTimePieChartList extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ExecutionTimePieChartList({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 필터링된 이벤트 목록
    final filteredEvents = actionEvents.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    // 액션별로 그룹화
    final groupedByAction = <String, List<ActionEventData>>{};
    for (var event in filteredEvents) {
      groupedByAction.putIfAbsent(event.actionName, () => []).add(event);
    }

    // 색상 리스트를 20개로 확장
    final colors = [
      TimeTrekTheme.vitaflowBrandColor,
      TimeTrekTheme.successColor,
      TimeTrekTheme.alertColor,
      TimeTrekTheme.proudMomentColor,
      const Color(0xFF845EC2), // 보라색
      const Color(0xFFD65DB1), // 분홍색
      const Color(0xFF4B4453), // 진회색
      const Color(0xFFFF9671), // 연한 주황색
      const Color(0xFFFFC75F), // 밝은 노란색
      const Color(0xFF008F7A), // 청록색
      const Color(0xFF0089BA), // 하늘색
      const Color(0xFFC34A36), // 붉은 갈색
      const Color(0xFF5B8C5A), // 초록색
      const Color(0xFFBC6C25), // 갈색
      const Color(0xFF6B4E71), // 자주색
      const Color(0xFF2D6A4F), // 진초록색
      const Color(0xFF9B2226), // 와인색
      const Color(0xFF48BFE3), // 밝은 파랑
      const Color(0xFF774936), // 다크 브라운
      const Color(0xFF6930C3), // 진보라색
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedByAction.length,
      itemBuilder: (context, index) {
        final actionName = groupedByAction.keys.elementAt(index);
        final events = groupedByAction[actionName]!;
        final color = colors[index % colors.length];
        
        return ExpansionTile(
          title: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(actionName)),
            ],
          ),
          children: events.map((event) => ListTile(
            title: Text(DateFormat('MM/dd HH:mm').format(event.startTime)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('상태: ${event.actionStatus}'),
                if (event.actionStatusDescription != null)
                  Text('설명: ${event.actionStatusDescription}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${event.actionExecutionTime}시간'),
                if (event.attachedImage != null)
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () {
                      // TODO: 이미지 보기 기능 구현
                    },
                  ),
                if (event.attachedFile != null)
                  IconButton(
                    icon: const Icon(Icons.file_present),
                    onPressed: () {
                      // TODO: 파일 다운로드 기능 구현
                    },
                  ),
              ],
            ),
          )).toList(),
        );
      },
    );
  }
}

class ActionHistoryTimeline extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ActionHistoryTimeline({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 필터링된 이벤트 목록
    final filteredEvents = actionEvents.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MM/dd HH:mm').format(event.startTime),
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    event.actionName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('상태: ${event.actionStatus}'),
                  Text('${event.actionExecutionTime}시간'),
                  if (event.attachedImage != null || event.attachedFile != null)
                    const Icon(Icons.attachment),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ActionHistoryTimelineList extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ActionHistoryTimelineList({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 필터링된 이벤트 목록
    final filteredEvents = actionEvents.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    // 액션별로 그룹화
    final groupedByAction = <String, List<ActionEventData>>{};
    for (var event in filteredEvents) {
      groupedByAction.putIfAbsent(event.actionName, () => []).add(event);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedByAction.length,
      itemBuilder: (context, index) {
        final actionName = groupedByAction.keys.elementAt(index);
        final events = groupedByAction[actionName]!;
        
        return ExpansionTile(
          title: Text(actionName),
          children: events.map((event) => ListTile(
            title: Text(DateFormat('MM/dd HH:mm').format(event.startTime)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('상태: ${event.actionStatus}'),
                if (event.actionStatusDescription != null)
                  Text('설명: ${event.actionStatusDescription}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${event.actionExecutionTime}시간'),
                if (event.attachedImage != null)
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: () {
                      // TODO: 이미지 보기 기능 구현
                    },
                  ),
                if (event.attachedFile != null)
                  IconButton(
                    icon: const Icon(Icons.file_present),
                    onPressed: () {
                      // TODO: 파일 다운로드 기능 구현
                    },
                  ),
              ],
            ),
          )).toList(),
        );
      },
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
    final url = Uri.parse('https://shsong83.app.n8n.cloud/webhook-test/timetrek-goal-evaluation');
    
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
