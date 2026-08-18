/// Thrown when the Misar.Blog dev-API returns a non-2xx response.
class MisarBlogException implements Exception {
  final int statusCode;
  final String message;

  /// The decoded error body when available (`null` if the body was not JSON).
  final Map<String, dynamic>? body;

  const MisarBlogException(this.statusCode, this.message, [this.body]);

  @override
  String toString() => 'MisarBlogException($statusCode): $message';
}

/// Thrown when the subscription attached to the API key blocks the call.
///
/// The API signals this with `code: "plan_limit_exceeded"` and answers 429 when
/// a metered allowance is exhausted (retryable once the period rolls over) or
/// 402 when the feature is locked outright. It is a distinct type rather than a
/// generic 429 because retrying cannot help until the allowance resets or the
/// plan changes — the client stops retrying as soon as it sees this code.
///
/// Surface [upgradeUrl] to the user rather than reporting a bare failure.
class MisarBlogPlanLimitException extends MisarBlogException {
  /// The account's current plan slug, when the API reports it.
  final String? plan;

  /// Pricing page to send the user to.
  final String? upgradeUrl;

  /// Seconds until the allowance resets, when the API supplies it.
  final int? retryAfter;

  /// The full upgrade offer from the response body.
  final Map<String, dynamic> upgrade;

  const MisarBlogPlanLimitException(
    int statusCode,
    String message, {
    this.plan,
    this.upgradeUrl,
    this.retryAfter,
    this.upgrade = const {},
    Map<String, dynamic>? body,
  }) : super(statusCode, message, body);

  /// Build from a decoded error body plus the response headers. Headers are
  /// authoritative; the offer body is the fallback when a proxy strips them.
  factory MisarBlogPlanLimitException.from(
    int status,
    Map<String, dynamic> body,
    Map<String, String> headers,
  ) {
    final h = {
      for (final e in headers.entries) e.key.toLowerCase(): e.value,
    };
    final offer = body['upgrade'] is Map<String, dynamic>
        ? body['upgrade'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final urls = offer['urls'];
    final currentPlan = offer['current_plan'];
    final retry = h['retry-after'];

    return MisarBlogPlanLimitException(
      status,
      (body['error'] as String?) ?? 'plan limit exceeded',
      plan: h['x-misar-plan'] ??
          (currentPlan is Map<String, dynamic>
              ? currentPlan['slug'] as String?
              : null),
      upgradeUrl: h['x-misar-upgrade-url'] ??
          (urls is Map<String, dynamic> ? urls['pricing'] as String? : null),
      retryAfter: retry == null ? null : int.tryParse(retry),
      upgrade: offer,
      body: body,
    );
  }

  @override
  String toString() =>
      'MisarBlogPlanLimitException($statusCode): $message (upgrade: $upgradeUrl)';
}

/// Thrown for connectivity failures where no HTTP response was received.
class MisarBlogNetworkException extends MisarBlogException {
  MisarBlogNetworkException(String message) : super(0, message);

  @override
  String toString() => 'MisarBlogNetworkException: $message';
}
