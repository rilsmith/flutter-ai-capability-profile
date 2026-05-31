import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/defaults.dart';
import '../models/application_domain.dart';
import '../models/dashboard_data.dart';
import '../utils/application_sync.dart';
import '../utils/json_export_web.dart'
    if (dart.library.io) '../utils/json_export_stub.dart';
import '../utils/migrate_application_domains.dart';

class DashboardNotifier extends ChangeNotifier {
  DashboardNotifier() {
    print('DashboardNotifier: Constructor started');
    _load();
  }

  DashboardData _data = defaultDashboardData;
  bool _initialized = false;
  Timer? _persistTimer;

  DashboardData get data => _data;
  bool get initialized => _initialized;

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

  DashboardData _mergeParsed(DashboardData parsed) {
    return defaultDashboardData.copyWith(
      title: parsed.title,
      subtitle: parsed.subtitle,
      intro: parsed.intro.isNotEmpty ? parsed.intro : defaultDashboardData.intro,
      dimensions: parsed.dimensions.isNotEmpty
          ? parsed.dimensions
          : defaultDashboardData.dimensions,
      applicationDomains: migrateApplicationDomains(
        parsed.applicationDomains.isNotEmpty
            ? parsed.applicationDomains
            : null,
        defaultDashboardData.applicationDomains,
      ),
      maturityScale: parsed.maturityScale.isNotEmpty
          ? parsed.maturityScale
          : defaultDashboardData.maturityScale,
      howToRead: parsed.howToRead,
      applicationHowToRead: parsed.applicationHowToRead.isNotEmpty
          ? parsed.applicationHowToRead
          : defaultDashboardData.applicationHowToRead,
      applicationMatrixHowToRead: parsed.applicationMatrixHowToRead.isNotEmpty
          ? parsed.applicationMatrixHowToRead
          : defaultDashboardData.applicationMatrixHowToRead,
      tiers: parsed.tiers,
      maxScore: parsed.maxScore,
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('SharedPreferences timeout'),
      );
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final parsed = DashboardData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _data = _mergeParsed(parsed);
      }
    } catch (_) {
      _data = defaultDashboardData;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(_data.toJson()));
  }

  void updateTitle(String title) {
    _data = _data.copyWith(title: title);
    notifyListeners();
    _schedulePersist();
  }

  void updateSubtitle(String subtitle) {
    _data = _data.copyWith(subtitle: subtitle);
    notifyListeners();
    _schedulePersist();
  }

  void updateIntro(String intro) {
    _data = _data.copyWith(intro: intro);
    notifyListeners();
    _schedulePersist();
  }

  void updateHowToRead(String howToRead) {
    _data = _data.copyWith(howToRead: howToRead);
    notifyListeners();
    _schedulePersist();
  }

  void updateApplicationHowToRead(String applicationHowToRead) {
    _data = _data.copyWith(applicationHowToRead: applicationHowToRead);
    notifyListeners();
    _schedulePersist();
  }

  void updateApplicationMatrixHowToRead(String applicationMatrixHowToRead) {
    _data = _data.copyWith(
      applicationMatrixHowToRead: applicationMatrixHowToRead,
    );
    notifyListeners();
    _schedulePersist();
  }

  void patchDimension(
    int id, {
    String? name,
    double? score,
    String? color,
    String? descriptor,
  }) {
    _data = _data.copyWith(
      dimensions: _data.dimensions
          .map(
            (d) => d.id == id
                ? d.copyWith(
                    name: name,
                    score: score,
                    color: color,
                    descriptor: descriptor,
                  )
                : d,
          )
          .toList(),
    );
    notifyListeners();
    _schedulePersist();
  }

  void patchApplicationDomain(
    int id, {
    String? name,
    String? shortName,
    DomainApplicability? applicability,
    DomainInvolvement? involvement,
    DomainSignal? value,
    DomainSignal? confidence,
    List<int>? capabilityIds,
  }) {
    _data = _data.copyWith(
      applicationDomains: _data.applicationDomains.map((domain) {
        if (domain.id != id) return domain;

        if (applicability != null &&
            applicability != domain.applicability) {
          return domainWhenApplicabilityChanges(applicability, domain);
        }

        return domain.copyWith(
          name: name,
          shortName: shortName,
          applicability: applicability,
          involvement: involvement,
          value: value,
          confidence: confidence,
          capabilityIds: capabilityIds,
        );
      }).toList(),
    );
    notifyListeners();
    _schedulePersist();
  }

  void cycleDomainInvolvement(int domainId) {
    _data = _data.copyWith(
      applicationDomains: _data.applicationDomains.map((domain) {
        if (domain.id != domainId || domain.isNotApplicable) return domain;
        return domain.copyWith(
          involvement: cycleInvolvement(domain.involvement),
        );
      }).toList(),
    );
    notifyListeners();
    _schedulePersist();
  }

  void toggleDomainCapability(int domainId, int capabilityId) {
    _data = _data.copyWith(
      applicationDomains: _data.applicationDomains.map((domain) {
        if (domain.id != domainId || domain.isNotApplicable) return domain;
        return domain.copyWith(
          capabilityIds: toggleCapabilityIds(domain, capabilityId),
        );
      }).toList(),
    );
    notifyListeners();
    _schedulePersist();
  }

  Future<void> resetToDefaults() async {
    _data = defaultDashboardData;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    notifyListeners();
  }

  void exportJson() {
    exportDashboardJson(jsonEncode(_data.toJson()));
  }

  Future<bool> importJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return false;
    }

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      return false;
    }

    try {
      final parsed = DashboardData.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
      _data = _mergeParsed(parsed);
      notifyListeners();
      await _persist();
      return true;
    } catch (_) {
      return false;
    }
  }
}
