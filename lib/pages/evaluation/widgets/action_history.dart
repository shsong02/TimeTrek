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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isExpanded
                  ? MediaQuery.of(context).size.height * 0.7
                  : MediaQuery.of(context).size.height * 0.3, // 기본 높이 설정
              child: SingleChildScrollView(
                child: Container(
                  height: isExpanded
                      ? MediaQuery.of(context).size.height * 0.7
                      : MediaQuery.of(context).size.height * 0.3, // 명시적인 높이 설정
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
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => _buildImageError(),
      cacheManager: CacheManager(
        Config(
          'customCacheKey',
          stalePeriod: const Duration(hours: 5),
        ),
      ),
      imageBuilder: (context, imageProvider) {
        final isCached = DefaultCacheManager().getFileFromCache(imageUrl) != null;
        print('이미지 다운로드 완료: $imageUrl, 캐시에서 로드됨: $isCached');
        return Image(image: imageProvider, fit: BoxFit.cover);
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

    // Goal과 날짜별로 그룹화
    final groupedEvents = <String, Map<String, List<ActionHistoryData>>>{};
    for (var event in filteredEvents) {
      final goalName = event.goalName;
      final date = DateFormat('yyyy-MM-dd').format(event.timestamp ?? DateTime.now());

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
        children: groupedEvents.entries.map((goalEntry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(goalEntry.key, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ...goalEntry.value.entries.map((dateEntry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateEntry.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Container(
                      height: 120,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                              .toList() ?? [];

                          return Row(
                            children: imageUrls.map((imageUrl) => FutureBuilder<String?>(
                              future: _getActualImageUrl(imageUrl),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: Center(child: CircularProgressIndicator()),
                                    ),
                                  );
                                }

                                final actualImageUrl = snapshot.data;
                                if (actualImageUrl == null) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: AspectRatio(
                                      aspectRatio: 1.0,
                                      child: _buildImageError(),
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: AspectRatio(
                                    aspectRatio: 1.0,
                                    child: GestureDetector(
                                      onTap: () => _handleImageTap(context, imageUrl),
                                      child: Hero(
                                        tag: imageUrl,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: _buildImageContent(actualImageUrl),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )).toList(),
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