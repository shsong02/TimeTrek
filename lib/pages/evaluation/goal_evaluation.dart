import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';


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
          const TabBar(
            tabs: [
              Tab(text: '일간 요약'),
              Tab(text: '주간 요약'),
              Tab(text: '월간 요약'),
            ],
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
          // 필터링 UI
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // 태그 필터
                Wrap(
                  spacing: 8.0,
                  children: allTags.map((tag) {
                    return FilterChip(
                      label: Text(tag),
                      selected: selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                // Completed 상태 토글
                SwitchListTile(
                  title: const Text('완료된 항목 숨기기'),
                  value: hideCompleted,
                  onChanged: (value) {
                    setState(() {
                      hideCompleted = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // 오늘의 진행 상황
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '오늘의 진행 상황',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                // 차트와 체크리스트
                Card(
                  child: Column(
                    children: [
                      ProgressLineChart(
                        actionEvents: widget.actionEvents,
                        startTime: todayStart,
                        endTime: todayEnd,
                        timegroup: '',
                        tag: selectedTags,
                        noActionStatus: hideCompleted ? ['completed'] : [],
                      ),
                      ProgressLineChartCheckList(
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '내일 예정된 항목',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                // 동일한 위젯들을 내일 날짜로 구성
                Card(
                  child: Column(
                    children: [
                      ProgressLineChart(
                        actionEvents: widget.actionEvents,
                        startTime: tomorrowStart,
                        endTime: tomorrowEnd,
                        timegroup: '',
                        tag: selectedTags,
                        noActionStatus: hideCompleted ? ['completed'] : [],
                      ),
                      ProgressLineChartCheckList(
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
  bool hideCompleted = false;
  final PageController _pageController = PageController();
  late List<DateTime> weekStartDates;

  @override
  void initState() {
    super.initState();
    // 최근 4주의 시작일 계산
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    weekStartDates = List.generate(4, (index) {
      return currentWeekStart.subtract(Duration(days: 7 * index));
    }).reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 상태 토글
        SwitchListTile(
          title: const Text('완료된 항목 숨기기'),
          value: hideCompleted,
          onChanged: (value) {
            setState(() {
              hideCompleted = value;
            });
          },
        ),
        
        // 주간 캐러셀
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: weekStartDates.length,
            itemBuilder: (context, index) {
              final weekStart = weekStartDates[index];
              final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
              
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // 주차 표시
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '${DateFormat('MM/dd').format(weekStart)} - ${DateFormat('MM/dd').format(weekEnd)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    // 진행 상황 차트
                    Card(
                      child: Column(
                        children: [
                          ProgressLineChart(
                            actionEvents: widget.actionEvents,
                            startTime: weekStart,
                            endTime: weekEnd,
                            timegroup: '',
                            tag: const [],
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                          ProgressLineChartCheckList(
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
                            tag: const [],
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                          ExecutionTimePieChartList(
                            actionEvents: widget.actionEvents,
                            startTime: weekStart,
                            endTime: weekEnd,
                            timegroup: '',
                            tag: const [],
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
                            startTime: weekStart,
                            endTime: weekEnd,
                            timegroup: '',
                            tag: const [],
                            noActionStatus: hideCompleted ? ['completed'] : [],
                          ),
                          ActionHistoryTimelineList(
                            actionEvents: widget.actionEvents,
                            startTime: weekStart,
                            endTime: weekEnd,
                            timegroup: '',
                            tag: const [],
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
          // 필터링 UI
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // 태그 필터
                Wrap(
                  spacing: 8.0,
                  children: allTags.map((tag) {
                    return FilterChip(
                      label: Text(tag),
                      selected: selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                // Completed 상태 토글
                SwitchListTile(
                  title: const Text('완료된 항목 숨기기'),
                  value: hideCompleted,
                  onChanged: (value) {
                    setState(() {
                      hideCompleted = value;
                    });
                  },
                ),
              ],
            ),
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
                      ProgressLineChart(
                        actionEvents: widget.actionEvents,
                        startTime: monthStart,
                        endTime: monthEnd,
                        timegroup: '',
                        tag: selectedTags,
                        noActionStatus: hideCompleted ? ['completed'] : [],
                      ),
                      ProgressLineChartCheckList(
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

class ProgressLineChart extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ProgressLineChart({
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

    // 목표 라인과 실제 진행 라인 데이터 생성
    final targetLine = <FlSpot>[];
    final successLine = <FlSpot>[];
    
    if (filteredEvents.isNotEmpty) {
      double accumulatedTarget = 0;
      double accumulatedSuccess = 0;
      
      for (var event in filteredEvents) {
        final daysFromStart = event.startTime.difference(startTime).inDays.toDouble();
        
        accumulatedTarget += event.actionExecutionTime;
        targetLine.add(FlSpot(daysFromStart, accumulatedTarget));
        
        if (event.actionStatus == 'completed') {
          accumulatedSuccess += event.actionExecutionTime;
          successLine.add(FlSpot(daysFromStart, accumulatedSuccess));
        }
      }
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final date = startTime.add(Duration(days: value.toInt()));
                  return Text(DateFormat('MM/dd').format(date));
                },
              ),
            ),
          ),
          lineBarsData: [
            // 목표 라인
            LineChartBarData(
              spots: targetLine,
              color: Colors.blue,
              dotData: FlDotData(show: false),
              isCurved: true,
            ),
            // 실제 진행 라인
            LineChartBarData(
              spots: successLine,
              color: Colors.green,
              dotData: FlDotData(show: false),
              isCurved: true,
            ),
          ],
        ),
      ),
    );
  }
}

class ProgressLineChartCheckList extends StatelessWidget {
  final List<ActionEventData> actionEvents;
  final DateTime startTime;
  final DateTime endTime;

  const ProgressLineChartCheckList({
    Key? key,
    required this.actionEvents,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 지연된 액션 필터링
    final delayedActions = actionEvents.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isPastDue = event.endTime.isBefore(DateTime.now());
      final isNotCompleted = event.actionStatus != 'completed';
      
      return isInTimeRange && isPastDue && isNotCompleted;
    }).toList();

    // 목표별로 그룹화
    final groupedByGoal = <String, List<ActionEventData>>{};
    for (var action in delayedActions) {
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
          title: Text(goalName),
          children: actions.map((action) => ListTile(
            title: Text(action.actionName),
            subtitle: Text('상태: ${action.actionStatus}'),
            trailing: Text('${action.actionExecutionTime}시간'),
          )).toList(),
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

    // 파이 차트 섹션 데이터 생성
    final sections = actionTimes.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final actionTime = entry.value;
      final color = Colors.primaries[index % Colors.primaries.length];
      return PieChartSectionData(
        value: actionTime.value,
        title: '${index + 1}',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
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
    }).toList();

    // 액션별 실행 시간 합계 계산
    final actionTimes = <String, double>{};
    double totalTime = 0;
    for (var event in filteredEvents) {
      actionTimes.update(
        event.actionName,
        (value) => value + event.actionExecutionTime,
        ifAbsent: () => event.actionExecutionTime,
      );
      totalTime += event.actionExecutionTime;
    }

    // 실행 시간 비율로 정렬
    final sortedActions = actionTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedActions.length,
      itemBuilder: (context, index) {
        final action = sortedActions[index];
        final percentage = (action.value / totalTime * 100).toStringAsFixed(1);
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.primaries[index % Colors.primaries.length],
            child: Text('${index + 1}'),
          ),
          title: Text(action.key),
          trailing: Text('$percentage% (${action.value}시간)'),
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
