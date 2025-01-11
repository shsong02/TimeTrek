import 'package:cloud_firestore/cloud_firestore.dart';

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
  final int referenceImageCount;
  final int referenceFileCount;
  final List<String> referenceImageUrls;
  final List<String> referenceFileUrls;

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
    this.referenceImageCount = 0,
    this.referenceFileCount = 0,
    this.referenceImageUrls = const [],
    this.referenceFileUrls = const [],
  });

  factory ActionEventData.fromMergedData(
      Map<String, dynamic> calendarEvent, Map<String, dynamic> actionList) {
    return ActionEventData(
      actionId: actionList['id'] ?? calendarEvent['action_id'] ?? '',
      actionName:
          actionList['action_name'] ?? calendarEvent['action_name'] ?? '',
      goalName: actionList['goal_name'] ?? calendarEvent['goal_name'] ?? '',
      timegroup: actionList['timegroup'] ?? calendarEvent['timegroup'] ?? '',
      tags: List<String>.from(calendarEvent['goal_tag'] ?? []),
      actionStatus:
          actionList['action_status'] ?? calendarEvent['action_status'] ?? '',
      actionStatusDescription: calendarEvent['action_status_description'],
      actionExecutionTime: (actionList['action_execution_time'] ??
              calendarEvent['action_execution_time'] ??
              0)
          .toDouble(),
      startTime: (calendarEvent['startTime'] as Timestamp).toDate(),
      endTime: (calendarEvent['endTime'] as Timestamp).toDate(),
      attachedImage: calendarEvent['attached_image'],
      attachedFile: calendarEvent['attached_file'],
      referenceImageCount: calendarEvent['reference_image_count'] ?? 0,
      referenceFileCount: calendarEvent['reference_file_count'] ?? 0,
      referenceImageUrls:
          List<String>.from(calendarEvent['reference_image_urls'] ?? []),
      referenceFileUrls:
          List<String>.from(calendarEvent['reference_file_urls'] ?? []),
    );
  }

  factory ActionEventData.fromMap(Map<String, dynamic> map) {
    return ActionEventData(
      actionId: map['action_id'] ?? '',
      actionName: map['action_name'] ?? '',
      goalName: map['goal_name'] ?? '',
      timegroup: map['timegroup'] ?? '',
      tags: List<String>.from(map['goal_tag'] ?? []),
      actionStatus: map['action_status'] ?? '',
      actionStatusDescription: map['action_status_description'],
      actionExecutionTime: map['action_execution_time'] ?? 0.0,
      startTime: map['startTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startTime'])
          : DateTime.fromMillisecondsSinceEpoch(0),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : DateTime.fromMillisecondsSinceEpoch(0),
      attachedImage: map['attached_image'],
      attachedFile: map['attached_file'],
      referenceImageCount: map['reference_image_count'] ?? 0,
      referenceFileCount: map['reference_file_count'] ?? 0,
      referenceImageUrls: List<String>.from(map['reference_image_urls'] ?? []),
      referenceFileUrls: List<String>.from(map['reference_file_urls'] ?? []),
    );
  }
}

// ActionHistory 데이터 모델 추가
class ActionHistoryData {
  final String actionId;
  final String actionName;
  final String goalName;
  final DateTime timestamp;
  final String actionStatus;
  final String? actionStatusDescription;
  final String? attachedImage;
  final String? attachedFile;
  final String? attachedImageName;
  final String? attachedFileName;
  final double actionExecutionTime;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? timegroup;
  final List<String> tags;

  ActionHistoryData({
    required this.actionId,
    required this.actionName,
    required this.goalName,
    required this.timestamp,
    required this.actionStatus,
    this.actionStatusDescription,
    this.attachedImage,
    this.attachedFile,
    this.attachedImageName,
    this.attachedFileName,
    required this.actionExecutionTime,
    this.startTime,
    this.endTime,
    this.timegroup,
    this.tags = const [],
  });

  factory ActionHistoryData.fromMap(Map<String, dynamic> map) {
    return ActionHistoryData(
      actionId: map['action_id'] ?? '',
      actionName: map['action_name'] ?? '',
      goalName: map['goal_name'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      actionStatus: map['action_status'] ?? '',
      actionStatusDescription: map['action_status_description'],
      attachedImage: map['attached_image'],
      attachedFile: map['attached_file'],
      attachedImageName: map['attached_image_name'],
      attachedFileName: map['attached_file_name'],
      actionExecutionTime: (map['action_execution_time'] ?? 0).toDouble(),
      startTime: map['startTime'] is Timestamp
          ? (map['startTime'] as Timestamp).toDate()
          : null,
      endTime: map['endTime'] is Timestamp
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      timegroup: map['timegroup'],
      tags: List<String>.from(map['tags'] ?? []),
    );
  }
}
