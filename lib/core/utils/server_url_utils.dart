/// Canonicalizes a user-typed or persisted Odoo server URL so every code
/// path that produces or compares one (login, account switching, session
/// restore, stored-accounts identity checks) agrees on the same string.
///
/// Adds `https://` when no scheme is present, lowercases the scheme and
/// host (never the path -- some reverse-proxy setups mount Odoo under a
/// case-sensitive path segment), and strips any trailing slash(es).
String normalizeServerUrl(String url, {String defaultScheme = 'https://'}) {
  var trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    trimmed = '$defaultScheme$trimmed';
  }

  try {
    final uri = Uri.parse(trimmed);
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri
        .replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase(), path: path)
        .toString();
  } catch (_) {
    /// Malformed enough that `Uri.parse` can't make sense of it -- fall
    /// back to a plain trailing-slash strip rather than throwing, so a
    /// weird-but-still-usable URL doesn't crash whatever called this.
    var result = trimmed;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
