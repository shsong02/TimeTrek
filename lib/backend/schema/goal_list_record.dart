import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';

class GoalListRecord extends FirestoreRecord {
  GoalListRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "created_at" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "timegroup" field.
  String? _timegroup;
  String get timegroup => _timegroup ?? '';
  bool hasTimegroup() => _timegroup != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "tag" field.
  List<String>? _tag;
  List<String> get tag => _tag ?? const [];
  bool hasTag() => _tag != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _description = snapshotData['description'] as String?;
    _createdAt = snapshotData['created_at'] as DateTime?;
    _timegroup = snapshotData['timegroup'] as String?;
    _order = castToType<int>(snapshotData['order']);
    _tag = getDataList(snapshotData['tag']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('goal_list');

  static Stream<GoalListRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => GoalListRecord.fromSnapshot(s));

  static Future<GoalListRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => GoalListRecord.fromSnapshot(s));

  static GoalListRecord fromSnapshot(DocumentSnapshot snapshot) =>
      GoalListRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static GoalListRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      GoalListRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'GoalListRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is GoalListRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createGoalListRecordData({
  String? name,
  String? description,
  DateTime? createdAt,
  String? timegroup,
  int? order,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'description': description,
      'created_at': createdAt,
      'timegroup': timegroup,
      'order': order,
    }.withoutNulls,
  );

  return firestoreData;
}

class GoalListRecordDocumentEquality implements Equality<GoalListRecord> {
  const GoalListRecordDocumentEquality();

  @override
  bool equals(GoalListRecord? e1, GoalListRecord? e2) {
    const listEquality = ListEquality();
    return e1?.name == e2?.name &&
        e1?.description == e2?.description &&
        e1?.createdAt == e2?.createdAt &&
        e1?.timegroup == e2?.timegroup &&
        e1?.order == e2?.order &&
        listEquality.equals(e1?.tag, e2?.tag);
  }

  @override
  int hash(GoalListRecord? e) => const ListEquality().hash(
      [e?.name, e?.description, e?.createdAt, e?.timegroup, e?.order, e?.tag]);

  @override
  bool isValidKey(Object? o) => o is GoalListRecord;
}
