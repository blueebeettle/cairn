import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Returns a time-ordered UUIDv7 string per RFC 9562.
///
/// Every ID in the app comes from here. No other file calls the uuid package.
String newId() => _uuid.v7();
