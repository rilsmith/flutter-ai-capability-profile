import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/defaults.dart';
import '../models/application_domain.dart';
import '../models/dashboard_data.dart';
import '../utils/application_sync.dart';
import '../models/dimension.dart';
import '../utils/json_export_web.dart'
    if (dart.library.io) '../utils/json_export_stub.dart';
import '../utils/migrate_application_domains.dart';

class DashboardNotifier extends ChangeNotifier {
  DashboardNotifier({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _skipApiCalls = false {
    debugPrint('DashboardNotifier: Constructor started');
    _load();
  }

  /// Testing-only constructor that skips async SharedPreferences loading and
  /// uses the default dashboard data immediately. It also skips authenticated
  /// API calls unless a real HTTP client is provided.
  DashboardNotifier.forTesting({http.Client? httpClient, bool skipApiCalls = true})
      : _data = defaultDashboardData,
        _httpClient = httpClient ?? http.Client(),
        _initialized = true,
        _loadingLatest = false,
        _latestLoaded = skipApiCalls,
        _skipApiCalls = skipApiCalls;

  final http.Client _httpClient;
  final bool _skipApiCalls;
  DashboardData _data = defaultDashboardData;
  bool _initialized = false;
  Timer? _persistTimer;
  int? _previewDimensionId;
  double? _previewScore;
  bool _submitting = false;
  String? _submitSuccess;
  String? _submitError;
  bool _loadingLatest = false;
  String? _latestError;
  bool _latestLoaded = false;
  String? _lastLatestToken;

  DashboardData get data => _data;
  bool get initialized => _initialized;
  bool get submitting => _submitting;
  String? get submitSuccess => _submitSuccess;
  String? get submitError => _submitError;
  bool get loadingLatest => _loadingLatest;
  String? get latestError => _latestError;
  bool get latestLoaded => _latestLoaded;

  /// Dimensions with in-flight radar drag score overlaid (no persistence).
  List<Dimension> get effectiveDimensions {
    if (_previewDimensionId == null || _previewScore == null) {
      return _data.dimensions;
    }
    return _data.dimensions
        .map(
          (d) => d.id == _previewDimensionId
              ? d.copyWith(score: _previewScore!)
              : d,
        )
        .toList();
  }

  bool get isDragPreviewActive => _previewDimensionId != null;

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

  void setDragPreview(int dimensionId, double score) {
    if (_previewDimensionId == dimensionId && _previewScore == score) {
      return;
    }
    _previewDimensionId = dimensionId;
    _previewScore = score;
    notifyListeners();
  }

  void clearDragPreview() {
    if (_previewDimensionId == null) return;
    _previewDimensionId = null;
    _previewScore = null;
    notifyListeners();
  }

  void patchDimension(
    int id, {
    String? name,
    double? score,
    String? color,
    String? descriptor,
  }) {
    _previewDimensionId = null;
    _previewScore = null;
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

  void clearSubmitStatus() {
    if (_submitSuccess == null && _submitError == null) return;
    _submitSuccess = null;
    _submitError = null;
    notifyListeners();
  }

  /// Submit the current matrix snapshot to the backend.
  ///
  /// This method prevents duplicate submissions while a request is already in
  /// flight. On success, [submitSuccess] is set to a confirmation message and
  /// the caller should refresh downstream tabs. On failure, [submitError] is
  /// set to a readable message and the current matrix state is preserved so
  /// the user can retry.
  Future<void> submit(String token) async {
    if (_submitting) return;
    _submitting = true;
    _submitSuccess = null;
    _submitError = null;
    notifyListeners();

    try {
      final origin = kIsWeb ? Uri.base.origin : 'http://localhost:5000';
      final response = await _httpClient
          .post(
            Uri.parse('$origin/api/submissions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(_data.toJson()),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final id = result['id'] as String?;
        final submittedAt = result['submitted_at'] as String?;
        _submitSuccess = 'Submitted successfully';
        if (id != null && id.isNotEmpty) {
          final shortId = id.length > 8 ? id.substring(0, 8) : id;
          _submitSuccess = 'Submitted successfully (ID: $shortId)';
        }
        if (submittedAt != null && submittedAt.isNotEmpty) {
          _submitSuccess = '${_submitSuccess!} at $submittedAt';
        }
      } else {
        String message;
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          message = error['error'] as String? ??
              'Submission failed (${response.statusCode})';
        } catch (_) {
          message = 'Submission failed (${response.statusCode})';
        }
        _submitError = message;
      }
    } on TimeoutException {
      _submitError = 'Submission timed out. Please try again.';
    } catch (e) {
      _submitError = 'Submission failed: $e';
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// Fetch the authenticated user's latest submission from the backend and
  /// populate the SDLC matrix.
  ///
  /// A 404 response means the user has never submitted and is treated as an
  /// empty submission, falling back to the default matrix state without an
  /// error. Any other failure shows an error message and leaves the matrix
  /// editable with the default state.
  ///
  /// Calls are skipped when the same [token] has already been loaded unless
  /// [force] is true. The test constructor skips API calls entirely.
  Future<void> loadLatestSubmission(String token, {bool force = false}) async {
    if (_skipApiCalls) {
      _latestLoaded = true;
      return;
    }
    // Guard against concurrent loads and automatic retry loops triggered by
    // rebuilds during the async request.
    if (_loadingLatest) return;
    if (!force && _lastLatestToken == token && _latestLoaded) return;

    _lastLatestToken = token;
    _loadingLatest = true;
    _latestError = null;
    notifyListeners();

    try {
      final origin = kIsWeb ? Uri.base.origin : 'http://localhost:5000';
      final response = await _httpClient
          .get(
            Uri.parse('$origin/api/submissions/me'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        _data = defaultDashboardData;
        await _persist();
        _latestLoaded = true;
      } else if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = result['payload'] as Map<String, dynamic>?;
        if (payload != null) {
          // Merge with defaults so older/missing fields do not blank the matrix.
          _data = _mergeParsed(DashboardData.fromJson(payload));
          await _persist();
        }
        _latestLoaded = true;
      } else {
        String message;
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          message = error['error'] as String? ??
              'Failed to load latest submission (${response.statusCode})';
        } catch (_) {
          message = 'Failed to load latest submission (${response.statusCode})';
        }
        _latestError = message;
        _data = defaultDashboardData;
        _latestLoaded = true;
      }
    } on TimeoutException {
      _latestError = 'Loading latest submission timed out. Please try again.';
      _data = defaultDashboardData;
      _latestLoaded = true;
    } catch (e) {
      _latestError = 'Failed to load latest submission: $e';
      _data = defaultDashboardData;
      _latestLoaded = true;
    } finally {
      _loadingLatest = false;
      notifyListeners();
    }
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
