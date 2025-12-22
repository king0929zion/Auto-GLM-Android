/// Helper that constructs OpenAI-style endpoint URLs for various providers.
///
/// The repository supports only OpenAI-compatible providers, so we try to preserve
/// any existing `/v1` segments while also appending the missing ones when needed
/// (e.g. `https://api.openai.com` -> `https://api.openai.com/v1`).
class ModelUrlBuilder {
  static final _v1Segment = RegExp(r"/v1($|/)", caseSensitive: false);
  static final _chatCompletionsSuffix = RegExp(r"/chat/completions$", caseSensitive: false);
  static final _bigModelV4 = RegExp(r"/api/paas/v4($|/)", caseSensitive: false);

  /// Returns the trimmed base URL without trailing slashes.
  static String normalizeBaseUrl(String baseUrl) {
    var trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Base URL cannot be empty');
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Determines whether the base URL already carries a `/v1` segment.
  static bool containsV1Segment(String baseUrl) {
    final normalized = normalizeBaseUrl(baseUrl);
    try {
      final uri = Uri.parse(normalized);
      return _v1Segment.hasMatch(uri.path);
    } catch (_) {
      return _v1Segment.hasMatch(normalized);
    }
  }

  /// Builds the final URL for the OpenAI chat completions endpoint.
  static String buildChatCompletionsUrl(String baseUrl) {
    final normalized = normalizeBaseUrl(baseUrl);
    if (_chatCompletionsSuffix.hasMatch(normalized)) {
      return normalized;
    }
    if (_bigModelV4.hasMatch(normalized)) {
      return '$normalized/chat/completions';
    }
    final suffix = containsV1Segment(normalized) ? 'chat/completions' : 'v1/chat/completions';
    return '$normalized/$suffix';
  }

  /// Builds the final URL for fetching the models list.
  static String buildModelsUrl(String baseUrl) {
    final normalized = normalizeBaseUrl(baseUrl);
    final suffix = containsV1Segment(normalized) ? 'models' : 'v1/models';
    return '$normalized/$suffix';
  }
}
