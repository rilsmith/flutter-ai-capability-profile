/// Test-only impersonation state.
///
/// The selected uid is sent to the backend as an X-Act-As-Uid header on every
/// API call. The backend honors it only for users listed in its
/// IMPERSONATION_ALLOWED_UIDS environment variable, so this alone grants no
/// privileges — GitHub login still proves who the real caller is. The state
/// is in-memory only and is re-chosen on every login.
class Impersonation {
  static String? _uid;

  /// The uid currently being impersonated, or null when viewing as self.
  static String? get uid => _uid;

  /// True when an impersonation target is active.
  static bool get active => _uid != null && _uid!.isNotEmpty;

  /// Set or clear the impersonation target.
  static void setUid(String? value) =>
      _uid = (value != null && value.trim().isNotEmpty) ? value.trim() : null;

  /// Add the X-Act-As-Uid header to [headers] when impersonation is active.
  static void apply(Map<String, String> headers) {
    if (active) {
      headers['X-Act-As-Uid'] = _uid!;
    }
  }
}
