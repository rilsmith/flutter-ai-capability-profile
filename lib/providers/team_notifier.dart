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

enum TeamScope { team, org }

/// Aggregated capability-link counts parsed from team/org submissions.
///
/// [capabilityCounts] maps domainId -> capabilityId -> number of members who
/// linked that capability to that domain. [inScopeCounts] maps domainId ->
/// number of members who marked that domain as in scope (excluding members
/// who marked it N/A).
class TeamLinkCounts {
  const TeamLinkCounts({
    this.capabilityCounts = const {},
    this.inScopeCounts = const {},
  });

  final Map<int, Map<int, int>> capabilityCounts;
  final Map<int, int> inScopeCounts;

  /// Number of members who linked [capabilityId] to [domainId].
  int linkCount(int domainId, int capabilityId) =>
      capabilityCounts[domainId]?[capabilityId] ?? 0;

  /// Number of members with [domainId] in scope.
  int inScopeCount(int domainId) => inScopeCounts[domainId] ?? 0;

  /// Total member-domain links for [capabilityId] across all domains.
  int totalLinksForCapability(int capabilityId) {
    var total = 0;
    for (final counts in capabilityCounts.values) {
      total += counts[capabilityId] ?? 0;
    }
    return total;
  }
}

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
    bool isManager = false,
    TeamProfile? orgProfile,
    List<ApplicationDomain>? orgAggregateCoverageDomains,
    List<Dimension>? orgAggregateDimensions,
    int orgAggregateMemberCount = 0,
    TeamLinkCounts? linkCounts,
    TeamLinkCounts? orgLinkCounts,
  })  : _httpClient = http.Client(),
        _profile = profile ?? const TeamProfile(),
        _aggregateDomains = [],
        _aggregateDomainsOverride = aggregateCoverageDomains,
        _aggregateDimensionsOverride = aggregateDimensions,
        _aggregateMemberCount = aggregateMemberCount,
        _warnings = warnings ?? [],
        _initialized = true,
        _loading = false,
        _isManager = isManager,
        _orgProfile = orgProfile ?? const TeamProfile(),
        _orgAggregateDomains = [],
        _orgAggregateDomainsOverride = orgAggregateCoverageDomains,
        _orgAggregateDimensionsOverride = orgAggregateDimensions,
        _orgAggregateMemberCount = orgAggregateMemberCount,
        _linkCounts = linkCounts ?? const TeamLinkCounts(),
        _orgLinkCounts = orgLinkCounts ?? const TeamLinkCounts();

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
  TeamLinkCounts _linkCounts = const TeamLinkCounts();

  // Org-scoped state.
  TeamScope _orgScope = TeamScope.team;
  bool _orgIncludeSelf = true;
  bool _isManager = false;
  TeamProfile _orgProfile = const TeamProfile();
  List<_AggregateDomain> _orgAggregateDomains = [];
  List<Dimension> _orgAggregateDimensions = [];
  int _orgAggregateMemberCount = 0;
  List<ApplicationDomain>? _orgAggregateDomainsOverride;
  List<Dimension>? _orgAggregateDimensionsOverride;
  String? _orgError;
  bool _orgLoading = false;
  bool _hasAttemptedOrgFetch = false;
  TeamLinkCounts _orgLinkCounts = const TeamLinkCounts();

  TeamProfile get profile => _profile;
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;
  List<String> get warnings => _warnings;
  int get memberCount => _profile.members.length;
  int get aggregateMemberCount => _aggregateMemberCount;

  /// Aggregated capability-link counts across team submissions.
  TeamLinkCounts get linkCounts => _linkCounts;

  /// Aggregated capability-link counts across org submissions.
  TeamLinkCounts get orgLinkCounts => _orgLinkCounts;

  /// True when the authenticated user has at least one direct or indirect report.
  bool get isManager => _isManager;

  /// Current scope selected in the team tab.
  TeamScope get orgScope => _orgScope;

  /// Whether the user's own submission is included in org aggregates.
  bool get orgIncludeSelf => _orgIncludeSelf;

  /// Org-scoped member profile list.
  TeamProfile get orgProfile => _orgProfile;

  /// Number of members in the org aggregate.
  int get orgAggregateMemberCount => _orgAggregateMemberCount;

  /// Error from the last org data fetch, if any.
  String? get orgError => _orgError;

  /// Whether org data is currently loading.
  bool get orgLoading => _orgLoading;

  /// The aggregated org dimensions returned by the backend aggregate endpoint.
  List<Dimension> get orgAggregateDimensions {
    if (_orgAggregateDimensionsOverride != null) {
      return _orgAggregateDimensionsOverride!;
    }
    return _orgAggregateDimensions;
  }

  /// Convert backend org aggregate domains into [ApplicationDomain] objects for
  /// the SDLC Coverage panel.
  List<ApplicationDomain> get orgAggregateCoverageDomains {
    if (_orgAggregateDomainsOverride != null) {
      return _orgAggregateDomainsOverride!;
    }
    return _orgAggregateDomains.map((agg) {
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

  /// Switch between "My Team" and "My Org" views.
  void setOrgScope(TeamScope scope) {
    if (_orgScope == scope) return;
    _orgScope = scope;
    notifyListeners();
  }

  /// Toggle whether the user's own submission is included in org aggregates.
  void setOrgIncludeSelf(bool value) {
    if (_orgIncludeSelf == value) return;
    _orgIncludeSelf = value;
    notifyListeners();
    if (_lastToken != null) {
      fetchOrgData(_lastToken!, force: true);
    }
  }

  /// Fetch the latest org submissions and aggregate data from the backend.
  /// Calls are skipped when the same [token] has already been fetched unless
  /// [force] is true.
  Future<void> fetchOrgData(String token, {bool force = false}) async {
    if (!force && _lastToken == token && _hasAttemptedOrgFetch) return;

    _hasAttemptedOrgFetch = true;
    _orgLoading = true;
    _orgError = null;
    notifyListeners();

    try {
      final origin = apiOrigin();
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };
      final includeSelf = _orgIncludeSelf ? 'true' : 'false';
      final orgResp = await _httpClient
          .get(
            Uri.parse(
              '$origin/api/submissions/org?include_self=$includeSelf',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (orgResp.statusCode != 200) {
        throw Exception(
          'Failed to load org submissions (${orgResp.statusCode})',
        );
      }
      final orgData = jsonDecode(orgResp.body) as Map<String, dynamic>;
      final submissions = (orgData['submissions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final aggResp = await _httpClient
          .get(
            Uri.parse(
              '$origin/api/submissions/org/aggregate?include_self=$includeSelf',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));
      if (aggResp.statusCode != 200) {
        throw Exception(
          'Failed to load org aggregate (${aggResp.statusCode})',
        );
      }
      final aggData = jsonDecode(aggResp.body) as Map<String, dynamic>;

      _orgAggregateMemberCount = aggData['member_count'] as int? ?? 0;
      _isManager = _orgAggregateMemberCount > 0;
      _orgAggregateDomains = (aggData['domains'] as List<dynamic>? ?? [])
          .map((e) => _AggregateDomain.fromJson(e as Map<String, dynamic>))
          .toList();
      _orgAggregateDimensions = (aggData['dimensions'] as List<dynamic>? ?? [])
          .map((e) {
            final json = e as Map<String, dynamic>;
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
      final capabilityCounts = <int, Map<int, int>>{};
      final inScopeCounts = <int, int>{};
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
          _accumulateLinkCounts(payload, capabilityCounts, inScopeCounts);
          members.add(IndividualProfile(name: name, scores: scores));
        } catch (e) {
          _warnings.add(_warningName(sub, 'invalid submission ($e)'));
        }
      }

      _orgLinkCounts = _freezeLinkCounts(capabilityCounts, inScopeCounts);
      _orgProfile = TeamProfile(members: members);
      _orgLoading = false;
      notifyListeners();
    } catch (e) {
      _orgError = e.toString();
      _orgLoading = false;
      notifyListeners();
    }
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
      final capabilityCounts = <int, Map<int, int>>{};
      final inScopeCounts = <int, int>{};
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
          _accumulateLinkCounts(payload, capabilityCounts, inScopeCounts);
          members.add(IndividualProfile(name: name, scores: scores));
        } catch (e) {
          _warnings.add(_warningName(sub, 'invalid submission ($e)'));
        }
      }

      _linkCounts = _freezeLinkCounts(capabilityCounts, inScopeCounts);
      _profile = TeamProfile(members: members);
      _loading = false;
      notifyListeners();

      // Kick off org discovery in the background; isManager resolves once it
      // completes. Intentionally unawaited so team data is ready immediately.
      fetchOrgData(token);
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
    _linkCounts = const TeamLinkCounts();

    _orgScope = TeamScope.team;
    _orgIncludeSelf = true;
    _isManager = false;
    _orgProfile = const TeamProfile();
    _orgAggregateDomains = [];
    _orgAggregateDimensions = [];
    _orgAggregateMemberCount = 0;
    _orgAggregateDomainsOverride = null;
    _orgAggregateDimensionsOverride = null;
    _orgError = null;
    _orgLoading = false;
    _hasAttemptedOrgFetch = false;
    _orgLinkCounts = const TeamLinkCounts();

    notifyListeners();
  }

  /// Parse one submission payload's applicationDomains and accumulate
  /// capability-link counts into the provided mutable maps.
  void _accumulateLinkCounts(
    Map<String, dynamic> payload,
    Map<int, Map<int, int>> capabilityCounts,
    Map<int, int> inScopeCounts,
  ) {
    final applicationDomains = payload['applicationDomains'];
    if (applicationDomains is! List<dynamic>) return;
    for (final raw in applicationDomains) {
      if (raw is! Map<String, dynamic>) continue;
      final domainId = raw['id'] as int?;
      if (domainId == null) continue;
      final applicability = raw['applicability'] as String? ?? 'in_scope';
      if (applicability == 'not_applicable') continue;
      inScopeCounts[domainId] = (inScopeCounts[domainId] ?? 0) + 1;
      final capabilityIds = raw['capabilityIds'];
      if (capabilityIds is! List<dynamic>) continue;
      for (final capId in capabilityIds) {
        if (capId is int) {
          final perDomain = capabilityCounts.putIfAbsent(domainId, () => {});
          perDomain[capId] = (perDomain[capId] ?? 0) + 1;
        }
      }
    }
  }

  TeamLinkCounts _freezeLinkCounts(
    Map<int, Map<int, int>> capabilityCounts,
    Map<int, int> inScopeCounts,
  ) {
    return TeamLinkCounts(
      capabilityCounts: Map<int, Map<int, int>>.unmodifiable({
        for (final entry in capabilityCounts.entries)
          entry.key: Map<int, int>.unmodifiable(entry.value),
      }),
      inScopeCounts: Map<int, int>.unmodifiable(inScopeCounts),
    );
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