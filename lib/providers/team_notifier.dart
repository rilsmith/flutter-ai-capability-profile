import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/defaults.dart';
import '../models/application_domain.dart';
import '../models/dimension.dart';
import '../models/individual_profile.dart';
import '../models/team_profile.dart';
import '../utils/api_origin.dart';

class _AggregateDomain {
  const _AggregateDomain({
    required this.id,
    required this.name,
    required this.shortName,
    required this.involvementAverage,
    required this.inScopeCount,
    required this.notApplicableCount,
    required this.capabilityIds,
  });

  factory _AggregateDomain.fromJson(Map<String, dynamic> json) {
    return _AggregateDomain(
      id: json['id'] as int,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      involvementAverage: (json['involvement_average'] as num).toDouble(),
      inScopeCount: json['in_scope_count'] as int? ?? 0,
      notApplicableCount: json['not_applicable_count'] as int? ?? 0,
      capabilityIds: (json['capability_ids'] as List<dynamic>?)
              ?.map((id) => id as int)
              .toList() ??
          const [],
    );
  }

  final int id;
  final String name;
  final String shortName;
  final double involvementAverage;
  final int inScopeCount;
  final int notApplicableCount;
  final List<int> capabilityIds;
}

class TeamNotifier extends ChangeNotifier {
  TeamNotifier({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client() {
    _initialized = true;
    notifyListeners();
  }

  /// Testing-only constructor that bypasses backend calls and uses the provided
  /// profile and aggregate domains directly.
  TeamNotifier.forTesting({
    TeamProfile? profile,
    List<ApplicationDomain>? aggregateCoverageDomains,
    List<Dimension>? aggregateDimensions,
    int aggregateMemberCount = 0,
    List<String>? warnings,
  })  : _httpClient = http.Client(),
        _profile = profile ?? const TeamProfile(),
        _aggregateDomains = [],
        _aggregateDomainsOverride = aggregateCoverageDomains,
        _aggregateDimensionsOverride = aggregateDimensions,
        _aggregateMemberCount = aggregateMemberCount,
        _warnings = warnings ?? [],
        _initialized = true,
        _loading = false;

  final http.Client _httpClient;

  TeamProfile _profile = const TeamProfile();
  bool _initialized = false;
  List<ApplicationDomain>? _aggregateDomainsOverride;
  List<Dimension>? _aggregateDimensionsOverride;
  bool _loading = false;
  String? _error;
  String? _lastToken;
  bool _hasAttemptedFetch = false;
  List<_AggregateDomain> _aggregateDomains = [];
  List<Dimension> _aggregateDimensions = [];
  int _aggregateMemberCount = 0;
  List<String> _warnings = [];

  TeamProfile get profile => _profile;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  List<String> get warnings => _warnings;
  int get memberCount => _profile.members.length;
  int get aggregateMemberCount => _aggregateMemberCount;

  /// The aggregated team dimensions returned by the backend aggregate endpoint.
  List<Dimension> get aggregateDimensions {
    if (_aggregateDimensionsOverride != null) {
      return _aggregateDimensionsOverride!;
    }
    return _aggregateDimensions;
  }

  /// Convert backend aggregate domains into [ApplicationDomain] objects for the
  /// SDLC Coverage panel. Involvement is derived from the average involvement
  /// score so the existing coverage visualization can render the team picture.
  List<ApplicationDomain> get aggregateCoverageDomains {
    if (_aggregateDomainsOverride != null) {
      return _aggregateDomainsOverride!;
    }
    return _aggregateDomains.map((agg) {
      final DomainInvolvement involvement;
      if (agg.involvementAverage >= 1.5) {
        involvement = DomainInvolvement.regular;
      } else if (agg.involvementAverage >= 0.5) {
        involvement = DomainInvolvement.occasional;
      } else {
        involvement = DomainInvolvement.none;
      }

      final applicability =
          agg.inScopeCount == 0 && agg.notApplicableCount > 0
              ? DomainApplicability.notApplicable
              : DomainApplicability.inScope;

      return ApplicationDomain(
        id: agg.id,
        name: agg.name,
        shortName: agg.shortName,
        applicability: applicability,
        involvement: involvement,
        value: DomainSignal.low,
        confidence: DomainSignal.low,
        capabilityIds: agg.capabilityIds,
      );
    }).toList();
  }

  /// Fetch the latest team submissions and aggregate data from the backend.
  /// Calls are skipped when the same [token] has already been fetched unless
  /// [force] is true.
  Future<void> fetchTeamData(String token, {bool force = false}) async {
    if (!force && _lastToken == token && _hasAttemptedFetch) return;

    _lastToken = token;
    _hasAttemptedFetch = true;
    _loading = true;
    _error = null;
    _warnings = [];
    notifyListeners();

    try {
      final origin = apiOrigin();
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
      final teamResp = await _httpClient
          .get(Uri.parse('$origin/api/submissions/team'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (teamResp.statusCode != 200) {
        throw Exception(
          'Failed to load team submissions (${teamResp.statusCode})',
        );
      }
      final teamData = jsonDecode(teamResp.body) as Map<String, dynamic>;
      final submissions = (teamData['submissions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final aggResp = await _httpClient
          .get(Uri.parse('$origin/api/submissions/team/aggregate'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (aggResp.statusCode != 200) {
        throw Exception(
          'Failed to load team aggregate (${aggResp.statusCode})',
        );
      }
      final aggData = jsonDecode(aggResp.body) as Map<String, dynamic>;

      _aggregateMemberCount = aggData['member_count'] as int? ?? 0;
      _aggregateDomains = (aggData['domains'] as List<dynamic>? ?? [])
          .map((e) => _AggregateDomain.fromJson(e as Map<String, dynamic>))
          .toList();
      _aggregateDimensions = (aggData['dimensions'] as List<dynamic>? ?? [])
          .map((e) {
            final json = e as Map<String, dynamic>;
            // Merge aggregate dimension with default descriptor so cards that
            // need it (e.g., capability definition dialogs) have stable copy.
            final defaultDim = defaultDashboardData.dimensions
                .where((d) => d.id == json['id'] as int?)
                .firstOrNull;
            return Dimension(
              id: json['id'] as int,
              name: json['name'] as String,
              score: (json['average'] as num).toDouble(),
              color: json['color'] as String,
              descriptor: defaultDim?.descriptor ?? '',
            );
          })
          .toList();

      final members = <IndividualProfile>[];
      for (final sub in submissions) {
        try {
          final payload = sub['payload'] as Map<String, dynamic>?;
          if (payload == null) {
            _warnings.add(_warningName(sub, 'missing payload'));
            continue;
          }
          final rawDimensions = payload['dimensions'] as List<dynamic>?;
          if (rawDimensions == null || rawDimensions.isEmpty) {
            _warnings.add(_warningName(sub, 'missing dimensions'));
            continue;
          }
          final dims = rawDimensions
              .map((d) => Dimension.fromJson(d as Map<String, dynamic>))
              .toList();
          final scores = dims.map((d) => d.score).toList();
          while (scores.length < 5) {
            scores.add(0.0);
          }
          final displayName = sub['user_display_name'] as String?;
          final email = sub['user_email'] as String?;
          final uid = sub['user_uid'] as String?;
          final name = (displayName?.isNotEmpty == true)
              ? displayName!
              : (email?.isNotEmpty == true)
                  ? email!
                  : (uid?.isNotEmpty == true)
                      ? uid!
                      : 'Unknown';
          members.add(IndividualProfile(name: name, scores: scores));
        } catch (e) {
          _warnings.add(_warningName(sub, 'invalid submission ($e)'));
        }
      }

      _profile = TeamProfile(members: members);
      _loading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _profile = const TeamProfile();
    _aggregateDomains = [];
    _aggregateDimensions = [];
    _aggregateMemberCount = 0;
    _lastToken = null;
    _hasAttemptedFetch = false;
    _error = null;
    _warnings = [];
    _loading = false;
    notifyListeners();
  }

  String _warningName(Map<String, dynamic> sub, String reason) {
    final displayName = sub['user_display_name'] as String?;
    final email = sub['user_email'] as String?;
    final uid = sub['user_uid'] as String?;
    final name = (displayName?.isNotEmpty == true)
        ? displayName!
        : (email?.isNotEmpty == true)
            ? email!
            : (uid?.isNotEmpty == true)
                ? uid!
                : 'Unknown teammate';
    return '$name: $reason';
  }

  /// Testing-only helpers to set transient states without a backend call.
  void debugSetError(String message) {
    _error = message;
    _loading = false;
    notifyListeners();
  }

  void debugSetLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}