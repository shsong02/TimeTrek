import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';

class ActionHistoryRecord extends FirestoreRecord {
  ActionHistoryRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "action_id" field.
  DocumentReference? _actionId;
  DocumentReference? get actionId => _actionId;
  bool hasActionId() => _actionId != null;

  // "action_name" field.
  String? _actionName;
  String get actionName => _actionName ?? '';
  bool hasActionName() => _actionName != null;

  // "goal_name" field.
  String? _goalName;
  String get goalName => _goalName ?? '';
  bool hasGoalName() => _goalName != null;

  // "timestamp" field.
  DateTime? _timestamp;
  DateTime? get timestamp => _timestamp;
  bool hasTimestamp() => _timestamp != null;

  // "action_status" field.
  String? _actionStatus;
  String get actionStatus => _actionStatus ?? '';
  bool hasActionStatus() => _actionStatus != null;

  // "action_status_description" field.
  String? _actionStatusDescription;
  String get actionStatusDescription => _actionStatusDescription ?? '';
  bool hasActionStatusDescription() => _actionStatusDescription != null;

  // "attached_file" field.
  String? _attachedFile;
  String get attachedFile => _attachedFile ?? '';
  bool hasAttachedFile() => _attachedFile != null;

  // "attached_image" field.
  String? _attachedImage;
  String get attachedImage => _attachedImage ?? '';
  bool hasAttachedImage() => _attachedImage != null;

  // "action_execution_time" field.
  double? _actionExecutionTime;
  double get actionExecutionTime => _actionExecutionTime ?? 0.0;
  bool hasActionExecutionTime() => _actionExecutionTime != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _actionId = snapshotData['action_id'] as DocumentReference?;
    _actionName = snapshotData['action_name'] as String?;
    _goalName = snapshotData['goal_name'] as String?;
    _timestamp = snapshotData['timestamp'] as DateTime?;
    _actionStatus = snapshotData['action_status'] as String?;
    _actionStatusDescription =
        snapshotData['action_status_description'] as String?;
    _attachedFile = snapshotData['attached_file'] as String?;
    _attachedImage = snapshotData['attached_image'] as String?;
    _actionExecutionTime =
        castToType<double>(snapshotData['action_execution_time']);
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('action_history')
          : FirebaseFirestore.instance.collectionGroup('action_history');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('action_history').doc(id);

  static Stream<ActionHistoryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ActionHistoryRecord.fromSnapshot(s));

  static Future<ActionHistoryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ActionHistoryRecord.fromSnapshot(s));

  static ActionHistoryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ActionHistoryRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ActionHistoryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ActionHistoryRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ActionHistoryRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ActionHistoryRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createActionHistoryRecordData({
  DocumentReference? actionId,
  String? actionName,
  String? goalName,
  DateTime? timestamp,
  String? actionStatus,
  String? actionStatusDescription,
  String? attachedFile,
  String? attachedImage,
  double? actionExecutionTime,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'action_id': actionId,
      'action_name': actionName,
      'goal_name': goalName,
      'timestamp': timestamp,
      'action_status': actionStatus,
      'action_status_description': actionStatusDescription,
      'attached_file': attachedFile,
      'attached_image': attachedImage,
      'action_execution_time': actionExecutionTime,
    }.withoutNulls,
  );

  return firestoreData;
}

class ActionHistoryRecordDocumentEquality
    implements Equality<ActionHistoryRecord> {
  const ActionHistoryRecordDocumentEquality();

  @override
  bool equals(ActionHistoryRecord? e1, ActionHistoryRecord? e2) {
    return e1?.actionId == e2?.actionId &&
        e1?.actionName == e2?.actionName &&
        e1?.goalName == e2?.goalName &&
        e1?.timestamp == e2?.timestamp &&
        e1?.actionStatus == e2?.actionStatus &&
        e1?.actionStatusDescription == e2?.actionStatusDescription &&
        e1?.attachedFile == e2?.attachedFile &&
        e1?.attachedImage == e2?.attachedImage &&
        e1?.actionExecutionTime == e2?.actionExecutionTime;
  }

  @override
  int hash(ActionHistoryRecord? e) => const ListEquality().hash([
        e?.actionId,
        e?.actionName,
        e?.goalName,
        e?.timestamp,
        e?.actionStatus,
        e?.actionStatusDescription,
        e?.attachedFile,
        e?.attachedImage,
        e?.actionExecutionTime
      ]);

  @override
  bool isValidKey(Object? o) => o is ActionHistoryRecord;
}
