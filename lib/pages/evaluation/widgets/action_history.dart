import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../goal_evaluation.dart';  // ActionEventData 모델용
import 'package:timelines_plus/timelines_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart' as prefs;
import '../../../components/file_storage_utils.dart';

// ... ActionHistoryTimeline 클래스 전체
// ... ActionHistoryTimelineList 클래스 전체 
class ActionHistoryTimeline extends StatelessWidget {
  final List<ActionHistoryData> actionHistories;
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
      final isInTimeRange = (event.timestamp?.isBefore(endTime) ?? false) && 
                          (event.timestamp?.isAfter(startTime) ?? false);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList()
      ..sort((a, b) => (b.timestamp ?? DateTime.now())
          .compareTo(a.timestamp ?? DateTime.now()));

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
                        DateFormat('MM/dd HH:mm').format(event.timestamp ?? DateTime.now()),
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
  final List<ActionHistoryData> actionHistories;
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

  Future<String?> _getActualImageUrl(String? url) async {
    return FileStorageUtils.getActualImageUrl(url);
  }

  Widget _buildImageContent(String imageUrl) {
    // 로컬 파일 처리
    if (imageUrl.startsWith('file://')) {
      return Image.file(
        File(imageUrl.replaceFirst('file://', '')),
        fit: BoxFit.cover,
        cacheWidth: 300,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('로컬 이미지 로딩 오류: $error');
          return _buildImageError();
        },
      );
    }

    // 네트워크 이미지 처리
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      cacheWidth: 300,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('네트워크 이미지 로딩 오류:');
        debugPrint('에러 타입: ${error.runtimeType}');
        debugPrint('에러 메시지: $error');
        debugPrint('URL: $imageUrl');
        debugPrint('스택트레이스: $stackTrace');
        
        return _buildImageError();
      },
    );
  }

  Widget _buildImageError() {
    return Container(
      color: Colors.grey[200],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(height: 4),
          Text(
            '이미지를 불러올 수 없습니다',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = actionHistories.where((event) {
      final isInTimeRange = (event.timestamp?.isBefore(endTime) ?? false) && 
                           (event.timestamp?.isAfter(startTime) ?? false);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);
      
      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList();

    final eventsWithImages = filteredEvents.where((e) => 
      e.attachedImage != null && 
      e.attachedImage!.isNotEmpty
    ).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          if (eventsWithImages.isNotEmpty)
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: eventsWithImages.length,
                itemBuilder: (context, index) {
                  final event = eventsWithImages[index];
                  final imageUrls = event.attachedImage
                      ?.replaceAll('\n', '')
                      .replaceAll('\r', '')
                      .replaceAll(']', '')
                      .split(',')
                      .map((url) => url.trim())
                      .where((url) => url.isNotEmpty)
                      .toList() ?? [];
                  print('처리된 이미지 URLs: $imageUrls');

                  return Row(
                    children: imageUrls.map((imageUrl) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: GestureDetector(
                          onTap: () => _handleImageTap(context, imageUrl),
                          child: Hero(
                            tag: imageUrl,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: FutureBuilder<String?>(
                                future: _getActualImageUrl(imageUrl),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  
                                  return snapshot.data != null
                                      ? _buildImageContent(snapshot.data!)
                                      : _buildImageError();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                  );
                },
              ),
            ),

          if (filteredEvents.any((e) => e.attachedFile?.isNotEmpty ?? false))
            Card(
              margin: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width,
                  ),
                  child: DataTable(
                    columnSpacing: 12,
                    horizontalMargin: 12,
                    columns: const [
                      DataColumn(label: Text('파일명')),
                      DataColumn(label: Text('업로드 시간')),
                      DataColumn(label: Text('다운로드')),
                    ],
                    rows: filteredEvents
                        .where((e) => e.attachedFile?.isNotEmpty ?? false)
                        .map((e) => DataRow(cells: [
                              DataCell(Text(e.attachedFile ?? '알 수 없는 파일')),
                              DataCell(Text(
                                DateFormat('MM/dd HH:mm').format(e.startTime ?? DateTime.now())
                              )),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () async {
                                    final uri = Uri.parse(e.attachedFile!);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                ),
                              ),
                            ]))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleImageTap(BuildContext context, String imageUrl) async {
    try {
      final actualUrl = await FileStorageUtils.getActualImageUrl(imageUrl);
      if (actualUrl == null || !context.mounted) return;

      if (actualUrl.startsWith('data:image')) {
        _showImageDialog(context, actualUrl);
        return;
      }

      if (await FileStorageUtils.canOpenUrl(actualUrl)) {
        _showImageDialog(context, actualUrl);
      } else {
        final uri = Uri.parse(actualUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 열 수 없습니다')),
        );
      }
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: _buildImageContent(imageUrl),
        ),
      ),
    );
  }
}