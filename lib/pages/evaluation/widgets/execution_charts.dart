import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '/theme/time_trek_theme.dart';
import '../goal_evaluation.dart'; // ActionEventData 모델용
import '../models/action_event_data.dart';

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
      final isInTimeRange =
          event.startTime.isAfter(startTime) && event.endTime.isBefore(endTime);
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
      final isInTimeRange =
          event.startTime.isAfter(startTime) && event.endTime.isBefore(endTime);
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
          children: events
              .map((event) => ListTile(
                    title:
                        Text(DateFormat('MM/dd HH:mm').format(event.startTime)),
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
                  ))
              .toList(),
        );
      },
    );
  }
}
