import 'ops_site_store.dart';

/// Discover / share URL helpers for Autumn ops (T0; no secrets).
///
/// Canonical form: `{baseUrl}/autumn/ops/discover`
abstract final class AutumnOpsDiscover {
  AutumnOpsDiscover._();

  static const discoverPath = '/autumn/ops/discover';

  /// Build shareable discover URL from a site base.
  static String shareUrlForBase(String baseUrl) {
    final b = OpsSiteEntry.normalizeBaseUrl(baseUrl);
    if (b.isEmpty) {
      return '';
    }
    return '$b$discoverPath';
  }

  /// Parse host deep link / https discover URL into baseUrl.
  ///
  /// Returns null when [raw] is not an ops discover intent.
  /// Accepts:
  /// - `https://host/autumn/ops/discover` (optional query/fragment)
  /// - 宿主自定义 scheme：`{scheme}://…/autumnops?base=`（任意非 http(s) scheme）
  ///
  /// Bare `http(s)://host` alone is **not** discover (avoid hijacking normal links).
  /// Callers that already know intent (e.g. Add Site paste) may set [forceHttpBase].
  static String? tryParseBaseUrl(String raw, {bool forceHttpBase = false}) {
    final s = raw.trim();
    if (s.isEmpty) {
      return null;
    }

    final customBase = _parseCustomSchemeAutumnOps(s);
    if (customBase != null) {
      return OpsSiteEntry.normalizeBaseUrl(customBase);
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

/// Host deep link: `{anyNonHttpScheme}://…/autumnops?base=` (or host `vc` + path `autumnops`).
String? _parseCustomSchemeAutumnOps(String s) {
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } catch (_) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme.isEmpty || scheme == 'http' || scheme == 'https') {
    return null;
  }
  final segs = uri.pathSegments.where((e) => e.isNotEmpty).toList();
  final hostVc = uri.host.toLowerCase() == 'vc';
  final isAutumnOpsPath = (hostVc && segs.isNotEmpty && segs.first == 'autumnops') ||
      segs.contains('autumnops');
  final queryBase = uri.queryParameters['base'] ??
      uri.queryParameters['url'] ??
      uri.queryParameters['u'];
  if (isAutumnOpsPath && queryBase != null && queryBase.trim().isNotEmpty) {
    return queryBase.trim();
  }
  return null;
}
