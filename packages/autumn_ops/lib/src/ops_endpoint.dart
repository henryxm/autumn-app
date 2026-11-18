import 'ops_client.dart';
import 'ops_probe_outcome.dart';
import 'ops_store.dart';

/// How [OpsEndpoint.resolve] classified the raw input.
enum OpsEndpointKind {
  /// User already typed `http://` or `https://` — no scheme auto-append.
  explicit,

  /// Hostname / domain — probe `https` then `http`.
  domain,

  /// IPv4 / IPv6 (incl. private / loopback) — probe `http` only.
  ip,
}

/// Ordered base-URL candidates for probe / enroll.
class OpsEndpointPlan {
  const OpsEndpointPlan({
    required this.kind,
    required this.candidates,
    required this.host,
  });

  final OpsEndpointKind kind;

  /// Ordered absolute base URLs (no trailing slash). Empty if input invalid.
  final List<String> candidates;

  /// Host used for classification (no scheme); empty when invalid.
  final String host;

  bool get isEmpty => candidates.isEmpty;
}

/// Resolve domain / IP / full URL into probe candidates.
///
/// Rules:
/// - Input already starts with `http://` or `https://` → use as-is (normalize
///   trailing slash only); no auto scheme join.
/// - Bare **IP** (incl. intranet / loopback / link-local) → `http://…` only.
/// - Bare **domain** → `https://…` then `http://…`.
class OpsEndpoint {
  OpsEndpoint._();

  static final RegExp _ipv4 = RegExp(
    r'^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}'
    r'(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$',
  );

  /// Strip trailing `/` and surrounding whitespace.
  static String normalizeBaseUrl(String u) {
    var s = u.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Build ordered probe candidates from user input.
  static OpsEndpointPlan resolve(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const OpsEndpointPlan(kind: OpsEndpointKind.domain, candidates: [], host: '');
    }

    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final base = normalizeBaseUrl(raw);
      final host = Uri.tryParse(base)?.host ?? '';
      return OpsEndpointPlan(
        kind: OpsEndpointKind.explicit,
        candidates: [base],
        host: host,
      );
    }

    // Allow //host or accidental scheme-less authority.
    var authorityPath = raw;
    if (authorityPath.startsWith('//')) {
      authorityPath = authorityPath.substring(2);
    }
    authorityPath = normalizeBaseUrl(authorityPath);
    if (authorityPath.isEmpty) {
      return const OpsEndpointPlan(kind: OpsEndpointKind.domain, candidates: [], host: '');
    }

    final host = _extractHost(authorityPath);
    if (host.isEmpty) {
      return const OpsEndpointPlan(kind: OpsEndpointKind.domain, candidates: [], host: '');
    }

    if (isIpLiteral(host)) {
      return OpsEndpointPlan(
        kind: OpsEndpointKind.ip,
        candidates: ['http://$authorityPath'],
        host: host,
      );
    }

    return OpsEndpointPlan(
      kind: OpsEndpointKind.domain,
      candidates: [
        'https://$authorityPath',
        'http://$authorityPath',
      ],
      host: host,
    );
  }

  /// True for IPv4 / IPv6 host literals (brackets optional for IPv6).
  static bool isIpLiteral(String host) {
    final h = host.trim().toLowerCase();
    if (h.isEmpty) return false;
    if (h.startsWith('[') && h.endsWith(']')) {
      return _isIpv6(h.substring(1, h.length - 1));
    }
    if (_ipv4.hasMatch(h)) return true;
    return _isIpv6(h);
  }

  /// Probe candidates in order; advance only on [OpsProbeKind.network].
  ///
  /// Returns the first non-network outcome (or the last network failure).
  static Future<OpsResolvedProbe> probePlan({
    required OpsEndpointPlan plan,
    required OpsStore store,
    bool hasLocalCert = false,
  }) async {
    if (plan.isEmpty) {
      return const OpsResolvedProbe(
        baseUrl: '',
        outcome: OpsProbeOutcome(
          kind: OpsProbeKind.network,
          message: '站点地址为空',
        ),
        tried: [],
      );
    }

    final tried = <String>[];
    OpsProbeOutcome? last;
    for (final base in plan.candidates) {
      tried.add(base);
      final client = AutumnOpsClient(baseUrl: base, store: store);
      final out = await client.probeOutcome(hasLocalCert: hasLocalCert);
      last = out;
      if (out.kind != OpsProbeKind.network) {
        return OpsResolvedProbe(baseUrl: base, outcome: out, tried: tried);
      }
    }
    return OpsResolvedProbe(
      baseUrl: plan.candidates.last,
      outcome: last!,
      tried: tried,
    );
  }

  static String _extractHost(String authorityPath) {
    // Uri needs a scheme to parse host reliably (IPv6 brackets, :port, path).
    final uri = Uri.tryParse('http://$authorityPath');
    if (uri == null) return '';
    return uri.host;
  }

  /// Minimal IPv6 check (hex groups / :: compression); not a full RFC parser.
  static bool _isIpv6(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty || !t.contains(':')) return false;
    if (t.split('::').length > 2) return false;

    // IPv4-mapped tail: ::ffff:192.168.1.1
    var core = t;
    if (t.contains('.')) {
      final lastColon = t.lastIndexOf(':');
      if (lastColon < 0) return false;
      final v4 = t.substring(lastColon + 1);
      if (!_ipv4.hasMatch(v4)) return false;
      core = t.substring(0, lastColon);
    }

    if (core.isEmpty) return true; // e.g. ::192.168.1.1 after stripping v4
    if (RegExp(r'[^0-9a-f:]').hasMatch(core)) return false;
    return true;
  }
}

/// Result of multi-candidate probe: winning [baseUrl] + [outcome].
class OpsResolvedProbe {
  const OpsResolvedProbe({
    required this.baseUrl,
    required this.outcome,
    required this.tried,
  });

  final String baseUrl;
  final OpsProbeOutcome outcome;
  final List<String> tried;
}
