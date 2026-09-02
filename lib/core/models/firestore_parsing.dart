/// Small parsing helpers shared by every model's `fromMap` factory.
///
/// Firestore hands back `dynamic`, and documents written by older builds of
/// the app are missing fields or hold the wrong type. Every model funnels
/// through these so a bad document degrades to a sensible default instead of
/// throwing somewhere up in the widget tree.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a string, treating null and non-strings as [fallback].
String asString(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

/// Reads a number as a double, tolerating ints and numeric strings.
double asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

/// Reads a number as an int, tolerating doubles and numeric strings.
int asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// Reads a bool, treating anything else as [fallback].
bool asBool(Object? value, {bool fallback = false}) =>
    value is bool ? value : fallback;

/// Converts a Firestore [Timestamp] to a [DateTime].
///
/// Returns null while a server timestamp is still pending, which is what the
/// local snapshot shows for the moment between writing and the server
/// resolving the value.
DateTime? asDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

/// Reads a list of strings, dropping any entry that isn't one.
List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

/// Reads a `Map<String, String>`, dropping entries with non-string values.
Map<String, String> asStringMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, String>{};
  value.forEach((key, entry) {
    if (key is String && entry is String) result[key] = entry;
  });
  return result;
}

/// Reads a `Map<String, int>`, dropping entries with non-numeric values.
Map<String, int> asIntMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, int>{};
  value.forEach((key, entry) {
    if (key is String && entry is num) result[key] = entry.toInt();
  });
  return result;
}

/// Reads a nested map, or null when the field is absent or the wrong type.
Map<String, dynamic>? asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return null;
}
