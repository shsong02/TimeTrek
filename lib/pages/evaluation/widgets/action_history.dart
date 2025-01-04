import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../goal_evaluation.dart';  // ActionEventData 모델용

// ... ActionHistoryTimeline 클래스 전체
// ... ActionHistoryTimelineList 클래스 전체 
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