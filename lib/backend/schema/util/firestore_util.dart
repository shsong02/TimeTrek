import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '/backend/schema/util/schema_util.dart';

typedef RecordBuilder<T> = T Function(DocumentSnapshot snapshot);

abstract class FirestoreRecord {
  FirestoreRecord(this.reference, this.snapshotData);
  Map<String, dynamic> snapshotData;
  DocumentReference reference;
}

abstract class FFFirebaseStruct extends BaseStruct {
  FFFirebaseStruct(this.firestoreUtilData);

  /// Utility class for Firestore updates
  FirestoreUtilData firestoreUtilData = FirestoreUtilData();
}

class FirestoreUtilData {
  const FirestoreUtilData({
    this.fieldValues = const {},
    this.clearUnsetFields = true,
    this.create = false,
    this.delete = false,
  });
  final Map<String, dynamic> fieldValues;
  final bool clearUnsetFields;
  final bool create;
  final bool delete;
  static String get name => 'firestoreUtilData';
}

extension MapDataExtensions on Map<String, dynamic> {
  Map<String, dynamic> get withoutNulls => Map.fromEntries(
        entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value)),
      );
}

Map<String, dynamic> mapFromFirestore(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is Timestamp) {
      return MapEntry(key, value.toDate());
    }
    if (value is DocumentReference) {
      return MapEntry(key, value);
    }
    return MapEntry(key, value);
  });
}

Map<String, dynamic> mapToFirestore(Map<String, dynamic> data) => data;



DocumentReference toRef(String ref) => FirebaseFirestore.instance.doc(ref);

T? safeGet<T>(T Function() func, [Function(dynamic)? reportError]) {
  try {
    return func();
  } catch (e) {
    reportError?.call(e);
  }
  return null;
}

Map<String, dynamic> mergeNestedFields(Map<String, dynamic> data) {
  final nestedData = data.where((k, _) => k.contains('.'));
  final fieldNames = nestedData.keys.map((k) => k.split('.').first).toSet();
  // Remove nested values (e.g. 'foo.bar') and merge them into a map.
  data.removeWhere((k, _) => k.contains('.'));
  fieldNames.forEach((name) {
    final mergedValues = mergeNestedFields(
      nestedData
          .where((k, _) => k.split('.').first == name)
          .map((k, v) => MapEntry(k.split('.').skip(1).join('.'), v)),
    );
    final existingValue = data[name];
    data[name] = {
      if (existingValue != null && existingValue is Map)
        ...existingValue as Map<String, dynamic>,
      ...mergedValues,
    };
  });
  // Merge any nested maps inside any of the fields as well.
  data.where((_, v) => v is Map).forEach((k, v) {
    data[k] = mergeNestedFields(v as Map<String, dynamic>);
  });

  return data;
}

extension _WhereMapExtension<K, V> on Map<K, V> {
  Map<K, V> where(bool Function(K, V) test) =>
      Map.fromEntries(entries.where((e) => test(e.key, e.value)));
}

DateTime get getCurrentTimestamp => DateTime.now();
