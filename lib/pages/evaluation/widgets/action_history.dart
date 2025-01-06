import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../goal_evaluation.dart'; // ActionEventData 모델용
import 'package:timelines_plus/timelines_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart' as prefs;
import '../../../components/file_storage_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:html' as html;

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
    bool isExpanded = false; // 확장 상태를 추적하기 위한 변수

    // filteredEvents 정의
    final filteredEvents = actionHistories.where((event) {
      final isInTimeRange = (event.timestamp?.isBefore(endTime) ?? false) &&
          (event.timestamp?.isAfter(startTime) ?? false);
      final isInTimegroup = timegroup.isEmpty || event.timegroup == timegroup;
      final hasTag = tag.isEmpty || tag.any((t) => event.tags.contains(t));
      final isNotExcluded = !noActionStatus.contains(event.actionStatus);

      return isInTimeRange && isInTimegroup && hasTag && isNotExcluded;
    }).toList();

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: Offset(0, 3), // 그림자의 위치 조정
              ),
            ],
            borderRadius: BorderRadius.circular(8.0), // 모서리 둥글게
          ),
          padding: const EdgeInsets.all(8.0), // 네 방향에 패딩 추가
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '타임라인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: isExpanded
                    ? MediaQuery.of(context).size.height * 0.7
                    : MediaQuery.of(context).size.height * 0.3, // 기본 높이 설정
                child: SingleChildScrollView(
                  child: Container(
                    height: isExpanded
                        ? MediaQuery.of(context).size.height * 0.7
                        : MediaQuery.of(context).size.height *
                            0.3, // 명시적인 높이 설정
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
                            padding:
                                const EdgeInsets.fromLTRB(12.0, 4.0, 8.0, 4.0),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      DateFormat('MM/dd HH:mm').format(
                                          event.timestamp ?? DateTime.now()),
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
                                    if (event.actionStatusDescription
                                            ?.isNotEmpty ??
                                        false)
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
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isExpanded = !isExpanded; // 확장 상태 토글
                  });
                },
                child: Text(
                  isExpanded ? '축소' : '확장',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      cacheKey: imageUrl,
      httpHeaders: const {
        'Access-Control-Allow-Origin': '*',
      },
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => _buildImageError(),
      cacheManager: DefaultCacheManager(),
      imageBuilder: (context, imageProvider) {
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            return child;
          },
        );
      },
      maxHeightDiskCache: 1024,
      memCacheHeight: 1024,
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

    // Goal과 날짜별로 그룹화
    final groupedEvents = <String, Map<String, List<ActionHistoryData>>>{};
    for (var event in filteredEvents) {
      final goalName = event.goalName;
      final date =
          DateFormat('yyyy-MM-dd').format(event.timestamp ?? DateTime.now());

      if (!groupedEvents.containsKey(goalName)) {
        groupedEvents[goalName] = {};
      }
      if (!groupedEvents[goalName]!.containsKey(date)) {
        groupedEvents[goalName]![date] = [];
      }
      groupedEvents[goalName]![date]!.add(event);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '이미지 뷰어',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: groupedEvents.entries.map((goalEntry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goalEntry.key,
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          ...goalEntry.value.entries.map((dateEntry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateEntry.key,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600)),
                                Container(
                                  height: 120,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: dateEntry.value.length,
                                    itemBuilder: (context, index) {
                                      final event = dateEntry.value[index];
                                      final imageUrls = event.attachedImage
                                              ?.replaceAll('[', '')
                                              .replaceAll('\n', '')
                                              .replaceAll('\r', '')
                                              .replaceAll(']', '')
                                              .split(',')
                                              .map((url) => url.trim())
                                              .where((url) => url.isNotEmpty)
                                              .toList() ??
                                          [];

                                      return Row(
                                        children: imageUrls
                                            .map((imageUrl) =>
                                                FutureBuilder<String?>(
                                                  future: _getActualImageUrl(
                                                      imageUrl),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 8.0),
                                                        child: AspectRatio(
                                                          aspectRatio: 1.0,
                                                          child: Center(
                                                              child:
                                                                  CircularProgressIndicator()),
                                                        ),
                                                      );
                                                    }

                                                    final actualImageUrl =
                                                        snapshot.data;
                                                    if (actualImageUrl ==
                                                        null) {
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                right: 8.0),
                                                        child: AspectRatio(
                                                          aspectRatio: 1.0,
                                                          child:
                                                              _buildImageError(),
                                                        ),
                                                      );
                                                    }

                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 8.0),
                                                      child: AspectRatio(
                                                        aspectRatio: 1.0,
                                                        child: GestureDetector(
                                                          onTap: () =>
                                                              _handleImageTap(
                                                                  context,
                                                                  imageUrl),
                                                          child: Hero(
                                                            tag: imageUrl,
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8.0),
                                                              child: _buildImageContent(
                                                                  actualImageUrl),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ))
                                            .toList(),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    '파일 뷰어',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: groupedEvents.entries.map((goalEntry) {
                      // 파일이 있는 이벤트만 필터링
                      final eventsWithFiles =
                          goalEntry.value.map((date, events) {
                        return MapEntry(
                          date,
                          events
                              .where((e) =>
                                  e.attachedFileName?.isNotEmpty ?? false)
                              .toList(),
                        );
                      })
                            ..removeWhere((date, events) => events.isEmpty);

                      if (eventsWithFiles.isEmpty)
                        return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goalEntry.key,
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          ...eventsWithFiles.entries.map((dateEntry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(dateEntry.key,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600)),
                                ),
                                ...dateEntry.value.map((event) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: ListTile(
                                        title: Text(
                                          event.actionName,
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          DateFormat('HH:mm').format(
                                              event.timestamp ??
                                                  DateTime.now()),
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        trailing: TextButton(
                                          onPressed: () async {
                                            if (event.attachedFile != null) {
                                              try {
                                                final url =
                                                    await FileStorageUtils
                                                        .getActualImageUrl(event
                                                            .attachedFile!);
                                                if (url != null) {
                                                  // 웹에서 직접 다운로드 링크 열기
                                                  final anchor =
                                                      html.AnchorElement(
                                                          href: url)
                                                        ..setAttribute(
                                                            'download',
                                                            event.attachedFileName ??
                                                                'download')
                                                        ..click();
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                          content: Text(
                                                              '파일을 다운로드할 수 없습니다')),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                        content: Text(
                                                            '파일 다운로드 중 오류가 발생했습니다')),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.download,
                                                  size: 16, color: Colors.blue),
                                              const SizedBox(width: 4),
                                              Text(
                                                event.attachedFileName ?? '',
                                                style: const TextStyle(
                                                  color: Colors.blue,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )),
                              ],
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
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
