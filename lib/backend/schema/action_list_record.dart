import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';

class ActionListRecord extends FirestoreRecord {
  ActionListRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "action_name" field.
  String? _actionName;
  String get actionName => _actionName ?? '';
  bool hasActionName() => _actionName != null;

  // "action_description" field.
  String? _actionDescription;
  String get actionDescription => _actionDescription ?? '';
  bool hasActionDescription() => _actionDescription != null;

  // "action_reason" field.
  String? _actionReason;
  String get actionReason => _actionReason ?? '';
  bool hasActionReason() => _actionReason != null;

  // "action_execution_time" field.
  double? _actionExecutionTime;
  double get actionExecutionTime => _actionExecutionTime ?? 0.0;
  bool hasActionExecutionTime() => _actionExecutionTime != null;

  // "goal_name" field.
  String? _goalName;
  String get goalName => _goalName ?? '';
  bool hasGoalName() => _goalName != null;

  // "timegroup" field.
  String? _timegroup;
  String get timegroup => _timegroup ?? '';
  bool hasTimegroup() => _timegroup != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "action_status" field.
  String? _actionStatus;
  String get actionStatus => _actionStatus ?? '';
  bool hasActionStatus() => _actionStatus != null;

  // "reference_image_count" field.
  int? _referenceImageCount;
  int get referenceImageCount => _referenceImageCount ?? 0;
  bool hasReferenceImageCount() => _referenceImageCount != null;

  // "reference_file_count" field.
  int? _referenceFileCount;
  int get referenceFileCount => _referenceFileCount ?? 0;
  bool hasReferenceFileCount() => _referenceFileCount != null;

  void _initializeFields() {
    _actionName = snapshotData['action_name'] as String?;
    _actionDescription = snapshotData['action_description'] as String?;
    _actionReason = snapshotData['action_reason'] as String?;
    _actionExecutionTime =
        castToType<double>(snapshotData['action_execution_time']);
    _goalName = snapshotData['goal_name'] as String?;
    _timegroup = snapshotData['timegroup'] as String?;
    _order = castToType<int>(snapshotData['order']);
    _actionStatus = snapshotData['action_status'] as String?;
    _referenceImageCount =
        castToType<int>(snapshotData['reference_image_count']);
    _referenceFileCount = castToType<int>(snapshotData['reference_file_count']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('action_list');

  static Stream<ActionListRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ActionListRecord.fromSnapshot(s));

  static Future<ActionListRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ActionListRecord.fromSnapshot(s));

  static ActionListRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ActionListRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ActionListRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ActionListRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ActionListRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ActionListRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createActionListRecordData({
  String? actionName,
  String? actionDescription,
  String? actionReason,
  double? actionExecutionTime,
  String? goalName,
  String? timegroup,
  int? order,
  String? actionStatus,
  int? referenceImageCount,
  int? referenceFileCount,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'action_name': actionName,
      'action_description': actionDescription,
      'action_reason': actionReason,
      'action_execution_time': actionExecutionTime,
      'goal_name': goalName,
      'timegroup': timegroup,
      'order': order,
      'action_status': actionStatus,
      'reference_image_count': referenceImageCount,
      'reference_file_count': referenceFileCount,
    }.withoutNulls,
  );

  return firestoreData;
}

class ActionListRecordDocumentEquality implements Equality<ActionListRecord> {
  const ActionListRecordDocumentEquality();

  @override
  bool equals(ActionListRecord? e1, ActionListRecord? e2) {
    return e1?.actionName == e2?.actionName &&
        e1?.actionDescription == e2?.actionDescription &&
        e1?.actionReason == e2?.actionReason &&
        e1?.actionExecutionTime == e2?.actionExecutionTime &&
        e1?.goalName == e2?.goalName &&
        e1?.timegroup == e2?.timegroup &&
        e1?.order == e2?.order &&
        e1?.actionStatus == e2?.actionStatus &&
        e1?.referenceImageCount == e2?.referenceImageCount &&
        e1?.referenceFileCount == e2?.referenceFileCount;
  }

  @override
  int hash(ActionListRecord? e) => const ListEquality().hash([
        e?.actionName,
        e?.actionDescription,
        e?.actionReason,
        e?.actionExecutionTime,
        e?.goalName,
        e?.timegroup,
        e?.order,
        e?.actionStatus,
        e?.referenceImageCount,
        e?.referenceFileCount
      ]);

  @override
  bool isValidKey(Object? o) => o is ActionListRecord;
}
