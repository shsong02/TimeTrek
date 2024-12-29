import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';

class TimeslotRecord extends FirestoreRecord {
  TimeslotRecord._(
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

  void _initializeFields() {
    _startTime = snapshotData['startTime'] as DateTime?;
    _endTime = snapshotData['endTime'] as DateTime?;
    _subject = snapshotData['subject'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('timeslot');

  static Stream<TimeslotRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TimeslotRecord.fromSnapshot(s));

  static Future<TimeslotRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TimeslotRecord.fromSnapshot(s));

  static TimeslotRecord fromSnapshot(DocumentSnapshot snapshot) =>
      TimeslotRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static TimeslotRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TimeslotRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TimeslotRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TimeslotRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTimeslotRecordData({
  DateTime? startTime,
  DateTime? endTime,
  String? subject,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
    }.withoutNulls,
  );

  return firestoreData;
}

class TimeslotRecordDocumentEquality implements Equality<TimeslotRecord> {
  const TimeslotRecordDocumentEquality();

  @override
  bool equals(TimeslotRecord? e1, TimeslotRecord? e2) {
    return e1?.startTime == e2?.startTime &&
        e1?.endTime == e2?.endTime &&
        e1?.subject == e2?.subject;
  }

  @override
  int hash(TimeslotRecord? e) =>
      const ListEquality().hash([e?.startTime, e?.endTime, e?.subject]);

  @override
  bool isValidKey(Object? o) => o is TimeslotRecord;
}
