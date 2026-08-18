/// Thrown when the Misar.Blog dev-API returns a non-2xx response.
class MisarBlogError implements Exception {
  final int status;
  final String message;

  /// The decoded error body when available (`null` if the body was not JSON).
  final Map<String, dynamic>? body;

  MisarBlogError(this.status, this.message, [this.body]);

  @override
  String toString() => 'MisarBlogError($status): $message';
}

/// Thrown when the subscription attached to the API key blocks the call.
///
/// The API signals this with `code: "plan_limit_exceeded"` and answers 429 when
/// a metered allowance is exhausted (retryable once the period rolls over) or
/// 402 when the feature is locked outright. It is a distinct type rather than a
/// generic 429 because retrying cannot help until the allowance resets or the
/// plan changes — the client stops retrying as soon as it sees this code.
class MisarBlogPlanLimitError extends MisarBlogError {
  /// The account's current plan slug, when the API reports it.
  final String? plan;

  /// Pricing page to send the user to.
  final String? upgradeUrl;

  /// Seconds until the allowance resets, when the API supplies it.
  final int? retryAfter;

  /// The full upgrade offer from the response body.
  final Map<String, dynamic> upgrade;

  MisarBlogPlanLimitError(
    int status,
    String message, {
    this.plan,
    this.upgradeUrl,
    this.retryAfter,
    this.upgrade = const {},
    Map<String, dynamic>? body,
  }) : super(status, message, body);

  /// Build from a decoded error body plus the response headers. Headers are
  /// authoritative; the offer body is the fallback when a proxy strips them.
  factory MisarBlogPlanLimitError.from(
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

    return MisarBlogPlanLimitError(
      status,
      (body['error'] as String?) ?? 'plan limit exceeded',
      plan: h['x-misar-plan'] ??
          (currentPlan is Map<String, dynamic> ? currentPlan['slug'] as String? : null),
      upgradeUrl: h['x-misar-upgrade-url'] ??
          (urls is Map<String, dynamic> ? urls['pricing'] as String? : null),
      retryAfter: retry == null ? null : int.tryParse(retry),
      upgrade: offer,
      body: body,
    );
  }

  @override
  String toString() =>
      'MisarBlogPlanLimitError($status): $message (upgrade: $upgradeUrl)';
}

/// Thrown for connectivity failures where no HTTP response was received.
class MisarBlogNetworkError extends MisarBlogError {
  MisarBlogNetworkError(String message) : super(0, message);

  @override
  String toString() => 'MisarBlogNetworkError: $message';
}
