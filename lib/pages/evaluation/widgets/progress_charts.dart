import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '/theme/time_trek_theme.dart';
import '../goal_evaluation.dart';  // ActionEventData 모델용

// ... ProgressBarChart 클래스 전체
// ... ProgressBarChartCheckList 클래스 전체
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
