import 'package:dio/dio.dart';

import 'ops_models.dart';

enum OpsProbeKind {
  network,
  incompatible,
  forbidden,
  pending,
  ready,
  needReset,
}

class OpsProbeOutcome {
  const OpsProbeOutcome({
    required this.kind,
    required this.message,
    this.result,
  });

  final OpsProbeKind kind;
  final String message;
  final OpsProbeResult? result;

  static OpsProbeOutcome fromSuccess(OpsProbeResult r, {bool hasLocalCert = false}) {
    if (!r.autumn) {
      return const OpsProbeOutcome(
        kind: OpsProbeKind.incompatible,
        message:
            'Autumn ops cert not deployed, or server is too old for this client',
      );
    }
    if (r.opsCert == 'ready' && hasLocalCert) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.ready,
        message: 'Enrolled; ready to manage',
        result: r,
      );
    }
    if (r.enrollAvailable && (r.opsCert == 'pending' || r.opsCert == 'none')) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.pending,
        message: 'Copy OpsEnroll secret= from the server console log',
        result: r,
      );
    }
    if (!r.enrollAvailable && !hasLocalCert) {
      return OpsProbeOutcome(
        kind: OpsProbeKind.needReset,
        message:
            'Site needs wall reset or DB clear of SECURITY_OPS_CERT_CONFIG before enroll',
        result: r,
      );
    }
    return OpsProbeOutcome(
      kind: OpsProbeKind.ready,
      message: 'Site reachable (opsCert=${r.opsCert})',
      result: r,
    );
  }

  static OpsProbeOutcome fromError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.badCertificate) {
        // Treat TLS failures as network so domain probe can fall through to http.
        return const OpsProbeOutcome(
          kind: OpsProbeKind.network,
          message: 'Cannot reach site; check URL and network',
        );
      }
      final code = e.response?.statusCode;
      if (code == 404) {
        return const OpsProbeOutcome(
          kind: OpsProbeKind.incompatible,
          message:
              'Autumn ops cert not deployed, or server is too old for this client',
        );
      }
      if (code == 403) {
        return const OpsProbeOutcome(
          kind: OpsProbeKind.forbidden,
          message:
              'Probe rejected; check gateway is not stripping X-Autumn-Ops-Probe',
        );
      }
      final data = e.response?.data;
      if (data is String && data.contains('<html')) {
        return const OpsProbeOutcome(
          kind: OpsProbeKind.incompatible,
          message:
              'Autumn ops cert not deployed, or server is too old for this client',
        );
      }
    }
    final msg = e.toString();
    if (msg.contains('FormatException') || msg.contains('empty response')) {
      return const OpsProbeOutcome(
        kind: OpsProbeKind.incompatible,
        message:
            'Autumn ops cert not deployed, or server is too old for this client',
      );
    }
    return OpsProbeOutcome(
      kind: OpsProbeKind.network,
      message: 'Cannot reach site; check URL and network ($e)',
    );
  }
}
