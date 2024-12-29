import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';

class TimeslotEventRecord extends FirestoreRecord {
  TimeslotEventRecord._(
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

  // "subject" field.
  String? _subject;
  String get subject => _subject ?? '';
  bool hasSubject() => _subject != null;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;

  void _initializeFields() {
    _startTime = snapshotData['startTime'] as DateTime?;
    _endTime = snapshotData['endTime'] as DateTime?;
    _subject = snapshotData['subject'] as String?;
    _type = snapshotData['type'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('timeslot_event');

  static Stream<TimeslotEventRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TimeslotEventRecord.fromSnapshot(s));

  static Future<TimeslotEventRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TimeslotEventRecord.fromSnapshot(s));

  static TimeslotEventRecord fromSnapshot(DocumentSnapshot snapshot) =>
      TimeslotEventRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static TimeslotEventRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TimeslotEventRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TimeslotEventRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TimeslotEventRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTimeslotEventRecordData({
  DateTime? startTime,
  DateTime? endTime,
  String? subject,
  String? type,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'type': type,
    }.withoutNulls,
  );

  return firestoreData;
}

class TimeslotEventRecordDocumentEquality
    implements Equality<TimeslotEventRecord> {
  const TimeslotEventRecordDocumentEquality();

  @override
  bool equals(TimeslotEventRecord? e1, TimeslotEventRecord? e2) {
    return e1?.startTime == e2?.startTime &&
        e1?.endTime == e2?.endTime &&
        e1?.subject == e2?.subject &&
        e1?.type == e2?.type;
  }

  @override
  int hash(TimeslotEventRecord? e) => const ListEquality()
      .hash([e?.startTime, e?.endTime, e?.subject, e?.type]);

  @override
  bool isValidKey(Object? o) => o is TimeslotEventRecord;
}
