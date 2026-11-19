import 'ops_site_store.dart';

/// Discover / share URL helpers for Autumn ops (T0; no secrets).
///
/// Canonical form: `{baseUrl}/ops/discover`
abstract final class AutumnOpsDiscover {
  AutumnOpsDiscover._();

  static const discoverPath = '/ops/discover';
  static const queryFlag = 'autumn_ops';

  /// Build shareable discover URL from a site base.
  static String shareUrlForBase(String baseUrl) {
    final b = OpsSiteEntry.normalizeBaseUrl(baseUrl);
    if (b.isEmpty) {
      return '';
    }
    return '$b$discoverPath';
  }

  /// Parse host deep link / https discover URL / flagged URL into baseUrl.
  ///
  /// Returns null when [raw] is not an ops discover intent.
  /// Accepts:
  /// - `https://host/ops/discover` (optional query/fragment)
  /// - `https://host/?autumn_ops=1` or `#autumn_ops`
  /// - `crchat://vc/autumnops?base=` / `xsign://` / `chaoranxin://`
  ///
  /// Bare `http(s)://host` alone is **not** discover (avoid hijacking normal links).
  /// Callers that already know intent may set [forceHttpBase].
  static String? tryParseBaseUrl(String raw, {bool forceHttpBase = false}) {
    final s = raw.trim();
    if (s.isEmpty) {
      return null;
    }

    final vcBase = _parseVcAutumnOps(s);
    if (vcBase != null) {
      return OpsSiteEntry.normalizeBaseUrl(vcBase);
    }

    final Uri uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    var pathNorm = uri.path;
    if (pathNorm.endsWith('/') && pathNorm.length > 1) {
      pathNorm = pathNorm.substring(0, pathNorm.length - 1);
    }

    if (pathNorm == discoverPath || pathNorm.endsWith(discoverPath)) {
      final origin = _originOf(uri);
      if (origin == null) {
        return null;
      }
      if (pathNorm == discoverPath) {
        return OpsSiteEntry.normalizeBaseUrl(origin);
      }
      final idx = pathNorm.lastIndexOf(discoverPath);
      final prefix = pathNorm.substring(0, idx);
      return OpsSiteEntry.normalizeBaseUrl('$origin$prefix');
    }

    final q = uri.queryParameters[queryFlag];
    final frag = uri.fragment;
    final flagged = q == '1' ||
        q == 'true' ||
        frag == queryFlag ||
        frag.startsWith('$queryFlag=');
    if (flagged) {
      return OpsSiteEntry.normalizeBaseUrl(_originWithPath(uri));
    }

    if (forceHttpBase) {
      return OpsSiteEntry.normalizeBaseUrl(_originWithPath(uri));
    }
    return null;
  }
}

String? _originOf(Uri uri) {
  if (uri.host.isEmpty) {
    return null;
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

String _originWithPath(Uri uri) {
  final origin = _originOf(uri) ?? '';
  var path = uri.path;
  if (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  return OpsSiteEntry.normalizeBaseUrl('$origin$path');
}

String? _parseVcAutumnOps(String s) {
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } catch (_) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  final appScheme = scheme == 'crchat' ||
      scheme == 'xsign' ||
      scheme == 'chaoranxin';
  final segs = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  final hostVc = uri.host.toLowerCase() == 'vc';
  final isAutumnOpsPath = (hostVc && segs.isNotEmpty && segs.first == 'autumnops') ||
      segs.contains('autumnops');
  final queryBase = uri.queryParameters['base'] ??
      uri.queryParameters['url'] ??
      uri.queryParameters['u'];
  if (appScheme && isAutumnOpsPath && queryBase != null && queryBase.trim().isNotEmpty) {
    return queryBase.trim();
  }
  return null;
}
