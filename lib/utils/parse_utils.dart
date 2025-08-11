import '../models/master.dart';

// Top-level function to parse a list of Map<String, dynamic> into a list of Master.
// This runs in a background isolate via `compute` to avoid blocking the UI thread.
List<Master> parseMasters(List<dynamic> data) {
  return data
      .map((e) => Master.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
} 