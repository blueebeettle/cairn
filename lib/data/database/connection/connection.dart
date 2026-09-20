import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens the platform-appropriate Drift database connection.
QueryExecutor openConnection({String name = 'focus_stack'}) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return NativeDatabase.memory();
  }
  return driftDatabase(name: name);
}
