import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:from_css_color/from_css_color.dart';
import 'firestore_util.dart';


export 'package:collection/collection.dart' show ListEquality;
export 'package:flutter/material.dart' show Color, Colors;

typedef StructBuilder<T> = T Function(Map<String, dynamic> data);

abstract class BaseStruct {
  Map<String, dynamic> toSerializableMap();
  String serialize() => json.encode(toSerializableMap());
}

enum ParamType {
  int,
  double,
  String,
  bool,
  DateTime,
  DateTimeRange,
  LatLng,
  Color,
  Json,
  Document,
  DocumentReference,
}

dynamic deserializeStructParam<T>(
  dynamic param,
  ParamType paramType,
  bool isList, {
  required StructBuilder<T> structBuilder,
}) {
  if (param == null) {
    return null;
  } else if (isList) {
    final paramValues;
    try {
      paramValues = param is Iterable ? param : json.decode(param);
    } catch (e) {
      return null;
    }
    if (paramValues is! Iterable) {
      return null;
    }
    return paramValues
        .map<T>((e) => deserializeStructParam<T>(e, paramType, false,
            structBuilder: structBuilder))
        .toList();
  } else if (param is Map<String, dynamic>) {
    return structBuilder(param);
  } else {
    return deserializeParam<T>(
      param,
      paramType,
      isList,
      structBuilder: structBuilder,
    );
  }
}

List<T>? getStructList<T>(
  dynamic value,
  StructBuilder<T> structBuilder,
) =>
    value is! List
        ? null
        : value
            .where((e) => e is Map<String, dynamic>)
            .map((e) => structBuilder(e as Map<String, dynamic>))
            .toList();

Color? getSchemaColor(dynamic value) => value is String
    ? fromCssColor(value)
    : value is Color
        ? value
        : null;

List<Color>? getColorsList(dynamic value) =>
    value is! List ? null : value.map(getSchemaColor).withoutNulls;

List<T>? getDataList<T>(dynamic value) =>
    value is! List ? null : value.map((e) => castToType<T>(e)!).toList();

T? castToType<T>(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is T) {
    return value;
  }
  try {
    if (T == double && value is num) {
      return value.toDouble() as T;
    }
    return value as T;
  } catch (_) {
    return null;
  }
}

dynamic deserializeParam<T>(
  dynamic param,
  ParamType paramType,
  bool isList, {
  StructBuilder<T>? structBuilder,
}) {
  if (param == null) return null;
  if (isList) {
    final paramValues = param is Iterable ? param : json.decode(param);
    if (paramValues is! Iterable) return null;
    return paramValues
        .map((e) => deserializeParam<T>(e, paramType, false))
        .toList();
  }
  switch (paramType) {
    case ParamType.int:
      return param.toString().toInt();
    case ParamType.double:
      return param.toString().toDouble();
    case ParamType.String:
      return param.toString();
    case ParamType.bool:
      return param.toString().toBool();
    case ParamType.DateTime:
      return DateTime.tryParse(param.toString());
    case ParamType.Json:
      return json.decode(param.toString());
    case ParamType.DocumentReference:
      return toRef(param.toString());
    default:
      return param;
  }
}

extension StringExtensions on String {
  int toInt() => int.parse(this);
  double toDouble() => double.parse(this);
  bool toBool() => toLowerCase() == 'true';
}

extension IterableExtensions<T> on Iterable<T?> {
  List<T> get withoutNulls => where((e) => e != null).cast<T>().toList();
}
