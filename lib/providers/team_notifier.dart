import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/individual_profile.dart';
import '../models/team_profile.dart';
import '../utils/csv_download_web.dart'
    if (dart.library.io) '../utils/csv_download_stub.dart';

const _teamStorageKey = 'team-profile-data';

class TeamNotifier extends ChangeNotifier {
  TeamNotifier() {
    _load();
  }

  TeamProfile _profile = const TeamProfile();
  bool _initialized = false;
  Timer? _persistTimer;

  TeamProfile get profile => _profile;
  bool get initialized => _initialized;
  int get memberCount => _profile.members.length;

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persist());
    });
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
      );
      final raw = prefs.getString(_teamStorageKey);
      if (raw != null) {
        _profile = TeamProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _profile = const TeamProfile();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamStorageKey, jsonEncode(_profile.toJson()));
  }

  void addMember(String name) {
    _profile = _profile.copyWith(
      members: [
        ..._profile.members,
        IndividualProfile(name: name, scores: List.filled(9, 3.0)),
      ],
    );
    notifyListeners();
    _schedulePersist();
  }

  void removeMember(int index) {
    final updated = List<IndividualProfile>.from(_profile.members)..removeAt(index);
    _profile = _profile.copyWith(members: updated);
    notifyListeners();
    _schedulePersist();
  }

  void updateMemberName(int index, String name) {
    final updated = List<IndividualProfile>.from(_profile.members);
    updated[index] = updated[index].copyWith(name: name);
    _profile = _profile.copyWith(members: updated);
    notifyListeners();
    _schedulePersist();
  }

  void updateMemberScore(int index, int dimensionIndex, double score) {
    final updated = List<IndividualProfile>.from(_profile.members);
    final scores = List<double>.from(updated[index].scores);
    scores[dimensionIndex] = score.clamp(1.0, 5.0);
    updated[index] = updated[index].copyWith(scores: scores);
    _profile = _profile.copyWith(members: updated);
    notifyListeners();
    _schedulePersist();
  }

  Future<void> resetToDefaults() async {
    _profile = const TeamProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_teamStorageKey);
    notifyListeners();
  }

  String exportCsv(List<String> dimensionNames) {
    final buffer = StringBuffer();
    buffer.write('Name');
    for (final name in dimensionNames) {
      buffer.write(',$name');
    }
    buffer.writeln();

    for (final member in _profile.members) {
      buffer.write(_escapeCsvField(member.name));
      for (final score in member.scores) {
        buffer.write(',${score.toStringAsFixed(1)}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<void> downloadCsv(List<String> dimensionNames) async {
    final csv = exportCsv(dimensionNames);
    await downloadCsvFile(csv, 'team-capability-scores.csv');
  }

  Future<({bool success, String? error})> importCsv({
    required List<int> bytes,
    required List<String> dimensionNames,
  }) async {
    try {
      final text = utf8.decode(bytes);
      final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

      if (lines.length < 2) {
        return (success: false, error: 'CSV must have a header row and at least one data row');
      }

      final expectedCount = 1 + dimensionNames.length;
      final members = <IndividualProfile>[];

      for (var i = 1; i < lines.length; i++) {
        final fields = _parseCsvLine(lines[i]);
        if (fields.length < expectedCount) {
          return (
            success: false,
            error: 'Row ${i + 1}: expected $expectedCount fields, got ${fields.length}',
          );
        }

        final name = fields[0].trim();
        final scores = <double>[];
        for (var j = 0; j < dimensionNames.length; j++) {
          final parsed = double.tryParse(fields[j + 1].trim());
          if (parsed == null) {
            return (
              success: false,
              error: 'Row ${i + 1}: invalid score "${fields[j + 1]}" for "${dimensionNames[j]}"',
            );
          }
          scores.add(parsed.clamp(1.0, 5.0));
        }

        members.add(IndividualProfile(name: name, scores: scores));
      }

      _profile = _profile.copyWith(members: members);
      notifyListeners();
      _schedulePersist();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Failed to parse CSV: $e');
    }
  }

  String _escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var current = '';
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current += char;
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(current);
          current = '';
        } else {
          current += char;
        }
      }
    }
    fields.add(current);
    return fields;
  }
}