import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../goal_evaluation.dart';  // ActionEventData 모델용
import 'package:timelines_plus/timelines_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// ... ActionHistoryTimeline 클래스 전체
// ... ActionHistoryTimelineList 클래스 전체 
class ActionHistoryTimeline extends StatelessWidget {
  final List<ActionEventData> actionHistories;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ActionHistoryTimeline({
    Key? key,
    required this.actionHistories,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
      final filteredEvents = actionHistories.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Timeline.tileBuilder(
        theme: TimelineThemeData(
          nodePosition: 0,
          connectorTheme: ConnectorThemeData(
            thickness: 1.5,
            color: Theme.of(context).dividerColor,
          ),
        ),
        builder: TimelineTileBuilder.connected(
          connectionDirection: ConnectionDirection.before,
          itemCount: filteredEvents.length,
          contentsBuilder: (_, index) {
            final event = filteredEvents[index];
            return Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 4.0, 8.0, 4.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MM/dd HH:mm').format(event.startTime),
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        event.goalName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        event.actionName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '상태: ${event.actionStatus}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (event.actionStatusDescription?.isNotEmpty ?? false)
                        Text(
                          '설명: ${event.actionStatusDescription}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      Text(
                        '소요시간: ${event.actionExecutionTime}시간',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          indicatorBuilder: (_, index) {
            return DotIndicator(
              size: 20,
              color: Theme.of(context).primaryColor,
              child: const Icon(
                Icons.event_note,
                size: 14,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}

class ActionHistoryTimelineList extends StatelessWidget {
  final List<ActionEventData> actionHistories;
  final DateTime startTime;
  final DateTime endTime;
  final String timegroup;
  final List<String> tag;
  final List<String> noActionStatus;

  const ActionHistoryTimelineList({
    Key? key,
    required this.actionHistories,
    required this.startTime,
    required this.endTime,
    required this.timegroup,
    required this.tag,
    required this.noActionStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final filteredEvents = actionHistories.where((event) {
      final isInTimeRange = event.startTime.isAfter(startTime) && 
                          event.endTime.isBefore(endTime);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return SingleChildScrollView(
      child: Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredEvents.length,
            itemBuilder: (context, index) {
              final event = filteredEvents[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  title: Text(event.actionName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.goalName),
                      Text(DateFormat('MM/dd HH:mm').format(event.startTime)),
                      Text('상태: ${event.actionStatus}'),
                      if (event.actionStatusDescription?.isNotEmpty ?? false)
                        Text('설명: ${event.actionStatusDescription}'),
                      Text('소요시간: ${event.actionExecutionTime}시간'),
                    ],
                  ),
                ),
              );
            },
          ),

          if (filteredEvents.any((e) => e.referenceImageUrls.isNotEmpty))
            SizedBox(
              height: 120,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: filteredEvents
                    .expand((e) => e.referenceImageUrls)
                    .toList()
                    .length,
                itemBuilder: (context, index) {
                  final imageUrl = filteredEvents
                      .expand((e) => e.referenceImageUrls)
                      .toList()[index];
                  final event = filteredEvents.firstWhere(
                    (e) => e.referenceImageUrls.contains(imageUrl)
                  );
                  
                  return GestureDetector(
                    onTap: () {
                      Scrollable.ensureVisible(
                        context,
                        alignment: 0.0,
                        duration: const Duration(milliseconds: 500),
                      );
                    },
                    child: Hero(
                      tag: imageUrl,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

          if (filteredEvents.any((e) => e.referenceFileUrls.isNotEmpty))
            Card(
              margin: const EdgeInsets.all(8.0),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('파일명')),
                  DataColumn(label: Text('업로드 시간')),
                  DataColumn(label: Text('다운로드')),
                ],
                rows: filteredEvents
                    .expand((e) => e.referenceFileUrls.map((url) => 
                      DataRow(cells: [
                        DataCell(Text(url.split('/').last)),
                        DataCell(Text(
                          DateFormat('MM/dd HH:mm').format(e.startTime)
                        )),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () async {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                        ),
                      ])
                    ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}