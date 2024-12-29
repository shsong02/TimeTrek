import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';

class CalendarEventRecord extends FirestoreRecord {
  CalendarEventRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "startTime" field.
  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  bool hasStartTime() => _startTime != null;

  // "endTime" field.
  DateTime? _endTime;
  DateTime? get endTime => _endTime;
  bool hasEndTime() => _endTime != null;

  // "action_name" field.
  String? _actionName;
  String get actionName => _actionName ?? '';
  bool hasActionName() => _actionName != null;

  // "action_status" field.
  String? _actionStatus;
  String get actionStatus => _actionStatus ?? '';
  bool hasActionStatus() => _actionStatus != null;

  // "action_execution_time" field.
  double? _actionExecutionTime;
  double get actionExecutionTime => _actionExecutionTime ?? 0.0;
  bool hasActionExecutionTime() => _actionExecutionTime != null;

  // "goal_name" field.
  String? _goalName;
  String get goalName => _goalName ?? '';
  bool hasGoalName() => _goalName != null;

  // "goal_order" field.
  int? _goalOrder;
  int get goalOrder => _goalOrder ?? 0;
  bool hasGoalOrder() => _goalOrder != null;

  // "action_order" field.
  int? _actionOrder;
  int get actionOrder => _actionOrder ?? 0;
  bool hasActionOrder() => _actionOrder != null;

  // "timegroup" field.
  String? _timegroup;
  String get timegroup => _timegroup ?? '';
  bool hasTimegroup() => _timegroup != null;

  // "reminder_minutes" field.
  int? _reminderMinutes;
  int get reminderMinutes => _reminderMinutes ?? 0;
  bool hasReminderMinutes() => _reminderMinutes != null;

  // "reminder_enabled" field.
  bool? _reminderEnabled;
  bool get reminderEnabled => _reminderEnabled ?? false;
  bool hasReminderEnabled() => _reminderEnabled != null;

  // "reminder_timestamp" field.
  DateTime? _reminderTimestamp;
  DateTime? get reminderTimestamp => _reminderTimestamp;
  bool hasReminderTimestamp() => _reminderTimestamp != null;

  // "goal_tag" field.
  List<String>? _goalTag;
  List<String> get goalTag => _goalTag ?? const [];
  bool hasGoalTag() => _goalTag != null;

  // "action_split_count" field.
  int? _actionSplitCount;
  int get actionSplitCount => _actionSplitCount ?? 0;
  bool hasActionSplitCount() => _actionSplitCount != null;

  // "action_split_num" field.
  int? _actionSplitNum;
  int get actionSplitNum => _actionSplitNum ?? 0;
  bool hasActionSplitNum() => _actionSplitNum != null;

  // "action_status_description" field.
  String? _actionStatusDescription;
  String get actionStatusDescription => _actionStatusDescription ?? '';
  bool hasActionStatusDescription() => _actionStatusDescription != null;

  void _initializeFields() {
    _startTime = snapshotData['startTime'] as DateTime?;
    _endTime = snapshotData['endTime'] as DateTime?;
    _actionName = snapshotData['action_name'] as String?;
    _actionStatus = snapshotData['action_status'] as String?;
    _actionExecutionTime =
        castToType<double>(snapshotData['action_execution_time']);
    _goalName = snapshotData['goal_name'] as String?;
    _goalOrder = castToType<int>(snapshotData['goal_order']);
    _actionOrder = castToType<int>(snapshotData['action_order']);
    _timegroup = snapshotData['timegroup'] as String?;
    _reminderMinutes = castToType<int>(snapshotData['reminder_minutes']);
    _reminderEnabled = snapshotData['reminder_enabled'] as bool?;
    _reminderTimestamp = snapshotData['reminder_timestamp'] as DateTime?;
    _goalTag = getDataList(snapshotData['goal_tag']);
    _actionSplitCount = castToType<int>(snapshotData['action_split_count']);
    _actionSplitNum = castToType<int>(snapshotData['action_split_num']);
    _actionStatusDescription =
        snapshotData['action_status_description'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('calendar_event');

  static Stream<CalendarEventRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CalendarEventRecord.fromSnapshot(s));

  static Future<CalendarEventRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CalendarEventRecord.fromSnapshot(s));

  static CalendarEventRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CalendarEventRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CalendarEventRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CalendarEventRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CalendarEventRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CalendarEventRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCalendarEventRecordData({
  DateTime? startTime,
  DateTime? endTime,
  String? actionName,
  String? actionStatus,
  double? actionExecutionTime,
  String? goalName,
  int? goalOrder,
  int? actionOrder,
  String? timegroup,
  int? reminderMinutes,
  bool? reminderEnabled,
  DateTime? reminderTimestamp,
  int? actionSplitCount,
  int? actionSplitNum,
  String? actionStatusDescription,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'action_name': actionName,
      'action_status': actionStatus,
      'action_execution_time': actionExecutionTime,
      'goal_name': goalName,
      'goal_order': goalOrder,
      'action_order': actionOrder,
      'timegroup': timegroup,
      'reminder_minutes': reminderMinutes,
      'reminder_enabled': reminderEnabled,
      'reminder_timestamp': reminderTimestamp,
      'action_split_count': actionSplitCount,
      'action_split_num': actionSplitNum,
      'action_status_description': actionStatusDescription,
    }.withoutNulls,
  );

  return firestoreData;
}

class CalendarEventRecordDocumentEquality
    implements Equality<CalendarEventRecord> {
  const CalendarEventRecordDocumentEquality();

  @override
  bool equals(CalendarEventRecord? e1, CalendarEventRecord? e2) {
    const listEquality = ListEquality();
    return e1?.startTime == e2?.startTime &&
        e1?.endTime == e2?.endTime &&
        e1?.actionName == e2?.actionName &&
        e1?.actionStatus == e2?.actionStatus &&
        e1?.actionExecutionTime == e2?.actionExecutionTime &&
        e1?.goalName == e2?.goalName &&
        e1?.goalOrder == e2?.goalOrder &&
        e1?.actionOrder == e2?.actionOrder &&
        e1?.timegroup == e2?.timegroup &&
        e1?.reminderMinutes == e2?.reminderMinutes &&
        e1?.reminderEnabled == e2?.reminderEnabled &&
        e1?.reminderTimestamp == e2?.reminderTimestamp &&
        listEquality.equals(e1?.goalTag, e2?.goalTag) &&
        e1?.actionSplitCount == e2?.actionSplitCount &&
        e1?.actionSplitNum == e2?.actionSplitNum &&
        e1?.actionStatusDescription == e2?.actionStatusDescription;
  }

  @override
  int hash(CalendarEventRecord? e) => const ListEquality().hash([
        e?.startTime,
        e?.endTime,
        e?.actionName,
        e?.actionStatus,
        e?.actionExecutionTime,
        e?.goalName,
        e?.goalOrder,
        e?.actionOrder,
        e?.timegroup,
        e?.reminderMinutes,
        e?.reminderEnabled,
        e?.reminderTimestamp,
        e?.goalTag,
        e?.actionSplitCount,
        e?.actionSplitNum,
        e?.actionStatusDescription
      ]);

  @override
  bool isValidKey(Object? o) => o is CalendarEventRecord;
}
