class OpsProbeResult {
  const OpsProbeResult({
    required this.autumn,
    required this.opsCert,
    required this.adminIpEnable,
    required this.enrollAvailable,
    this.siteId,
    this.serverFingerprint,
    this.protocolVersion,
  });

  final bool autumn;
  /// none | pending | ready
  final String opsCert;
  final bool adminIpEnable;
  final bool enrollAvailable;
  final String? siteId;
  final String? serverFingerprint;
  final int? protocolVersion;

  factory OpsProbeResult.fromJson(Map<String, dynamic> json) {
    return OpsProbeResult(
      autumn: json['autumn'] == true,
      opsCert: '${json['opsCert'] ?? 'none'}',
      adminIpEnable: json['adminIpEnable'] == true,
      enrollAvailable: json['enrollAvailable'] == true,
      siteId: json['siteId']?.toString(),
      serverFingerprint: json['serverFingerprint']?.toString(),
      protocolVersion: json['protocolVersion'] is int
          ? json['protocolVersion'] as int
          : int.tryParse('${json['protocolVersion'] ?? ''}'),
    );
  }
}

class OpsEnrollResult {
  const OpsEnrollResult({
    required this.certId,
    required this.siteId,
    required this.serverPublicKey,
    this.serverFingerprint,
  });

  final String certId;
  final String siteId;
  final String serverPublicKey;
  final String? serverFingerprint;

  factory OpsEnrollResult.fromJson(Map<String, dynamic> json) {
    return OpsEnrollResult(
      certId: '${json['certId'] ?? ''}',
      siteId: '${json['siteId'] ?? ''}',
      serverPublicKey: '${json['serverPublicKey'] ?? ''}',
      serverFingerprint: json['serverFingerprint']?.toString(),
    );
  }
}

/// 已登录设备签发的一次性认领码（明文仅本次响应）。
class OpsClaimIssueResult {
  const OpsClaimIssueResult({
    required this.claimId,
    required this.claimSecret,
    required this.expiresAt,
    this.siteId,
    this.serverFingerprint,
    this.label,
  });

  final String claimId;
  final String claimSecret;
  final int expiresAt;
  final String? siteId;
  final String? serverFingerprint;
  final String? label;

  factory OpsClaimIssueResult.fromJson(Map<String, dynamic> json) {
    return OpsClaimIssueResult(
      claimId: '${json['claimId'] ?? ''}',
      claimSecret: '${json['claimSecret'] ?? ''}',
      expiresAt: json['expiresAt'] is int
          ? json['expiresAt'] as int
          : int.tryParse('${json['expiresAt'] ?? ''}') ?? 0,
      siteId: json['siteId']?.toString(),
      serverFingerprint: json['serverFingerprint']?.toString(),
      label: json['label']?.toString(),
    );
  }
}

class OpsRevokeResult {
  const OpsRevokeResult({
    required this.success,
    required this.lastCert,
  });

  final bool success;
  final bool lastCert;

  factory OpsRevokeResult.fromJson(Map<String, dynamic> json) {
    return OpsRevokeResult(
      success: json['success'] == true,
      lastCert: json['lastCert'] == true,
    );
  }
}

/// 三类 IP 列表单行（管理 IP / 白名单 / 黑名单）。
class OpsIpRow {
  const OpsIpRow({
    required this.ip,
    this.tag,
    this.description,
    this.forbidden,
    this.available,
    this.createTimeMs,
  });

  final String ip;
  final String? tag;
  final String? description;

  /// 白名单类：`0` 启用 / `1` 禁用。
  final int? forbidden;

  /// 黑名单类：与 wall 一致——`0` 生效拦截 / `1` 停用。
  final int? available;
  final int? createTimeMs;

  bool get isForbidden => (forbidden ?? 0) == 1;

  /// 原始 `available==1`（停用态）；黑名单是否生效请用 [isBlackActive]。
  bool get isAvailable => (available ?? 0) == 1;

  /// 黑名单条目是否正在拦截（`available==0`）。
  bool get isBlackActive => (available ?? 1) == 0;

  factory OpsIpRow.fromJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}');
    }

    return OpsIpRow(
      ip: '${json['ip'] ?? ''}',
      tag: json['tag']?.toString(),
      description: json['description']?.toString(),
      forbidden: asInt(json['forbidden']),
      available: asInt(json['available']),
      createTimeMs: asInt(json['createTime']),
    );
  }
}

class OpsIpPage {
  const OpsIpPage({
    required this.count,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.list,
  });

  final int count;
  final int page;
  final int limit;
  final bool hasMore;
  final List<OpsIpRow> list;

  factory OpsIpPage.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('${v ?? ''}') ?? fallback;
    }

    final raw = json['list'];
    final rows = <OpsIpRow>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          rows.add(OpsIpRow.fromJson(e));
        } else if (e is Map) {
          rows.add(OpsIpRow.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final page = asInt(json['page'], 1);
    final limit = asInt(json['limit'], 20);
    final count = asInt(json['count'], rows.length);
    final hasMore = json['hasMore'] == true || page * limit < count;
    return OpsIpPage(
      count: count,
      page: page,
      limit: limit,
      hasMore: hasMore,
      list: rows,
    );
  }
}

/// 运维运行快照（`POST /ops/api/v1/runtime/snapshot`）。
class OpsRuntimeSnapshot {
  const OpsRuntimeSnapshot({
    required this.collectedAt,
    required this.system,
    required this.jvm,
    required this.disk,
    required this.database,
    required this.firewall,
    required this.traffic,
    required this.redis,
    required this.paths,
    this.exceptionsSupported = false,
  });

  final int collectedAt;
  final OpsRuntimeSystem system;
  final OpsRuntimeJvm jvm;
  final OpsRuntimeDisk disk;
  final OpsRuntimeDatabase database;
  final OpsRuntimeFirewall firewall;
  final OpsRuntimeTraffic traffic;
  final OpsRuntimeRedis redis;
  final OpsRuntimePaths paths;
  final bool exceptionsSupported;

  factory OpsRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) {
      final v = json[key];
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return const {};
    }

    final ex = section('exceptions');
    return OpsRuntimeSnapshot(
      collectedAt: _asInt(json['collectedAt'], 0),
      system: OpsRuntimeSystem.fromJson(section('system')),
      jvm: OpsRuntimeJvm.fromJson(section('jvm')),
      disk: OpsRuntimeDisk.fromJson(section('disk')),
      database: OpsRuntimeDatabase.fromJson(section('database')),
      firewall: OpsRuntimeFirewall.fromJson(section('firewall')),
      traffic: OpsRuntimeTraffic.fromJson(section('traffic')),
      redis: OpsRuntimeRedis.fromJson(section('redis')),
      paths: OpsRuntimePaths.fromJson(section('paths')),
      exceptionsSupported: ex['supported'] == true,
    );
  }
}

class OpsRuntimeSystem {
  const OpsRuntimeSystem({
    required this.available,
    this.error,
    this.hostname = '',
    this.osName = '',
    this.osArch = '',
    this.osVersion = '',
    this.availableProcessors = 0,
    this.systemLoadAverage,
    this.processCpuLoad,
    this.systemCpuLoad,
    this.physicalTotalBytes,
    this.physicalUsedBytes,
    this.physicalFreeBytes,
  });

  final bool available;
  final String? error;
  final String hostname;
  final String osName;
  final String osArch;
  final String osVersion;
  final int availableProcessors;
  final double? systemLoadAverage;
  final double? processCpuLoad;
  final double? systemCpuLoad;
  final int? physicalTotalBytes;
  final int? physicalUsedBytes;
  final int? physicalFreeBytes;

  factory OpsRuntimeSystem.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeSystem(
      available: json['available'] != false,
      error: json['error']?.toString(),
      hostname: '${json['hostname'] ?? ''}',
      osName: '${json['osName'] ?? ''}',
      osArch: '${json['osArch'] ?? ''}',
      osVersion: '${json['osVersion'] ?? ''}',
      availableProcessors: _asInt(json['availableProcessors'], 0),
      systemLoadAverage: _asDouble(json['systemLoadAverage']),
      processCpuLoad: _asDouble(json['processCpuLoad']),
      systemCpuLoad: _asDouble(json['systemCpuLoad']),
      physicalTotalBytes: _asIntOrNull(json['physicalTotalBytes']),
      physicalUsedBytes: _asIntOrNull(json['physicalUsedBytes']),
      physicalFreeBytes: _asIntOrNull(json['physicalFreeBytes']),
    );
  }
}

class OpsRuntimeJvm {
  const OpsRuntimeJvm({
    required this.available,
    this.error,
    this.uptimeMs = 0,
    this.javaVersion = '',
    this.vmName = '',
    this.heap,
    this.nonHeap,
    this.threadLive = 0,
    this.threadDaemon = 0,
    this.threadPeak = 0,
  });

  final bool available;
  final String? error;
  final int uptimeMs;
  final String javaVersion;
  final String vmName;
  final OpsRuntimeMemory? heap;
  final OpsRuntimeMemory? nonHeap;
  final int threadLive;
  final int threadDaemon;
  final int threadPeak;

  factory OpsRuntimeJvm.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeJvm(
      available: json['available'] != false,
      error: json['error']?.toString(),
      uptimeMs: _asInt(json['uptimeMs'], 0),
      javaVersion: '${json['javaVersion'] ?? ''}',
      vmName: '${json['vmName'] ?? ''}',
      heap: OpsRuntimeMemory.tryParse(json['heap']),
      nonHeap: OpsRuntimeMemory.tryParse(json['nonHeap']),
      threadLive: _asInt(json['threadLive'], 0),
      threadDaemon: _asInt(json['threadDaemon'], 0),
      threadPeak: _asInt(json['threadPeak'], 0),
    );
  }
}

class OpsRuntimeMemory {
  const OpsRuntimeMemory({
    required this.used,
    required this.committed,
    required this.max,
    this.init = 0,
  });

  final int used;
  final int committed;
  final int max;
  final int init;

  double get usedRatio {
    final denom = max > 0 ? max : (committed > 0 ? committed : 0);
    if (denom <= 0) return 0;
    return (used / denom).clamp(0.0, 1.0);
  }

  static OpsRuntimeMemory? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return OpsRuntimeMemory(
      init: _asInt(m['init'], 0),
      used: _asInt(m['used'], 0),
      committed: _asInt(m['committed'], 0),
      max: _asInt(m['max'], 0),
    );
  }
}

class OpsRuntimeDisk {
  const OpsRuntimeDisk({
    required this.available,
    this.error,
    this.volumes = const [],
  });

  final bool available;
  final String? error;
  final List<OpsRuntimeDiskVolume> volumes;

  factory OpsRuntimeDisk.fromJson(Map<String, dynamic> json) {
    final raw = json['volumes'];
    final list = <OpsRuntimeDiskVolume>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          list.add(OpsRuntimeDiskVolume.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return OpsRuntimeDisk(
      available: json['available'] != false,
      error: json['error']?.toString(),
      volumes: list,
    );
  }
}

class OpsRuntimeDiskVolume {
  const OpsRuntimeDiskVolume({
    required this.name,
    required this.path,
    required this.available,
    this.error,
    this.totalBytes = 0,
    this.usableBytes = 0,
    this.usedBytes = 0,
  });

  final String name;
  final String path;
  final bool available;
  final String? error;
  final int totalBytes;
  final int usableBytes;
  final int usedBytes;

  double get usedRatio {
    if (totalBytes <= 0) return 0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }

  factory OpsRuntimeDiskVolume.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeDiskVolume(
      name: '${json['name'] ?? ''}',
      path: '${json['path'] ?? ''}',
      available: json['available'] == true,
      error: json['error']?.toString(),
      totalBytes: _asInt(json['totalBytes'], 0),
      usableBytes: _asInt(json['usableBytes'], 0),
      usedBytes: _asInt(json['usedBytes'], 0),
    );
  }
}

class OpsRuntimeDatabase {
  const OpsRuntimeDatabase({
    required this.available,
    this.error,
    this.poolType = '',
    this.productName = '',
    this.productVersion = '',
    this.url = '',
    this.activeCount,
    this.poolingCount,
    this.waitThreadCount,
    this.maxActive,
    this.minIdle,
    this.tableCount,
    this.tableCountError,
  });

  final bool available;
  final String? error;
  final String poolType;
  final String productName;
  final String productVersion;
  final String url;
  final int? activeCount;
  final int? poolingCount;
  final int? waitThreadCount;
  final int? maxActive;
  final int? minIdle;
  final int? tableCount;
  final String? tableCountError;

  factory OpsRuntimeDatabase.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeDatabase(
      available: json['available'] == true,
      error: json['error']?.toString(),
      poolType: '${json['poolType'] ?? ''}',
      productName: '${json['productName'] ?? ''}',
      productVersion: '${json['productVersion'] ?? ''}',
      url: '${json['url'] ?? ''}',
      activeCount: _asIntOrNull(json['activeCount']),
      poolingCount: _asIntOrNull(json['poolingCount']),
      waitThreadCount: _asIntOrNull(json['waitThreadCount']),
      maxActive: _asIntOrNull(json['maxActive']),
      minIdle: _asIntOrNull(json['minIdle']),
      tableCount: _asIntOrNull(json['tableCount']),
      tableCountError: json['tableCountError']?.toString(),
    );
  }
}

class OpsRuntimeFirewall {
  const OpsRuntimeFirewall({
    required this.available,
    this.error,
    this.adminIpEnable = false,
    this.adminIpCount = 0,
    this.ipWhiteCount = 0,
    this.ipBlackCount = 0,
    this.firewallCount = 0,
    this.shieldAttack = false,
    this.shieldPrint = false,
    this.shieldEnabled = false,
    this.shieldAllowedIpCount = 0,
    this.shieldAllowedIpSample = const [],
    this.blackTopToday = const [],
  });

  final bool available;
  final String? error;
  final bool adminIpEnable;
  final int adminIpCount;
  final int ipWhiteCount;
  final int ipBlackCount;
  final int firewallCount;
  final bool shieldAttack;
  final bool shieldPrint;
  final bool shieldEnabled;
  final int shieldAllowedIpCount;
  final List<String> shieldAllowedIpSample;
  final List<OpsRuntimeBlackHit> blackTopToday;

  factory OpsRuntimeFirewall.fromJson(Map<String, dynamic> json) {
    final sample = <String>[];
    final rawSample = json['shieldAllowedIpSample'];
    if (rawSample is List) {
      for (final e in rawSample) {
        final s = '$e'.trim();
        if (s.isNotEmpty) sample.add(s);
      }
    }
    final top = <OpsRuntimeBlackHit>[];
    final rawTop = json['blackTopToday'];
    if (rawTop is List) {
      for (final e in rawTop) {
        if (e is Map) {
          top.add(OpsRuntimeBlackHit.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return OpsRuntimeFirewall(
      available: json['available'] != false,
      error: json['error']?.toString(),
      adminIpEnable: json['adminIpEnable'] == true,
      adminIpCount: _asInt(json['adminIpCount'], 0),
      ipWhiteCount: _asInt(json['ipWhiteCount'], 0),
      ipBlackCount: _asInt(json['ipBlackCount'], 0),
      firewallCount: _asInt(json['firewallCount'], 0),
      shieldAttack: json['shieldAttack'] == true,
      shieldPrint: json['shieldPrint'] == true,
      shieldEnabled: json['shieldEnabled'] == true,
      shieldAllowedIpCount: _asInt(json['shieldAllowedIpCount'], 0),
      shieldAllowedIpSample: sample,
      blackTopToday: top,
    );
  }
}

class OpsRuntimeBlackHit {
  const OpsRuntimeBlackHit({
    required this.ip,
    this.today = 0,
    this.count = 0,
    this.tag,
    this.available,
  });

  final String ip;
  final int today;
  final int count;
  final String? tag;
  final int? available;

  factory OpsRuntimeBlackHit.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeBlackHit(
      ip: '${json['ip'] ?? ''}',
      today: _asInt(json['today'], 0),
      count: _asInt(json['count'], 0),
      tag: json['tag']?.toString(),
      available: _asIntOrNull(json['available']),
    );
  }
}

class OpsRuntimeTraffic {
  const OpsRuntimeTraffic({
    required this.available,
    this.error,
    this.requestTotal = 0,
    this.approxQps = 0,
    this.visitLogDay,
    this.pageViewToday,
    this.uniqueVisitorToday,
    this.visitLogRowsToday,
    this.visitLogError,
  });

  final bool available;
  final String? error;
  final int requestTotal;
  final double approxQps;
  final String? visitLogDay;
  final int? pageViewToday;
  final int? uniqueVisitorToday;
  final int? visitLogRowsToday;
  final String? visitLogError;

  factory OpsRuntimeTraffic.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeTraffic(
      available: json['available'] != false,
      error: json['error']?.toString(),
      requestTotal: _asInt(json['requestTotal'], 0),
      approxQps: _asDouble(json['approxQps']) ?? 0,
      visitLogDay: json['visitLogDay']?.toString(),
      pageViewToday: _asIntOrNull(json['pageViewToday']),
      uniqueVisitorToday: _asIntOrNull(json['uniqueVisitorToday']),
      visitLogRowsToday: _asIntOrNull(json['visitLogRowsToday']),
      visitLogError: json['visitLogError']?.toString(),
    );
  }
}

class OpsRuntimeRedis {
  const OpsRuntimeRedis({
    required this.enabled,
    required this.available,
    this.error,
    this.version,
    this.connectedClients,
    this.usedMemory,
    this.keyCount,
    this.usedMemoryBytes,
  });

  final bool enabled;
  final bool available;
  final String? error;
  final String? version;
  final String? connectedClients;
  final String? usedMemory;
  final int? keyCount;
  final int? usedMemoryBytes;

  factory OpsRuntimeRedis.fromJson(Map<String, dynamic> json) {
    return OpsRuntimeRedis(
      enabled: json['enabled'] == true,
      available: json['available'] == true,
      error: json['error']?.toString(),
      version: json['version']?.toString(),
      connectedClients: json['connected_clients']?.toString(),
      usedMemory: json['used_memory']?.toString(),
      keyCount: _asIntOrNull(json['keyCount']),
      usedMemoryBytes: _asIntOrNull(json['usedMemoryBytes']),
    );
  }
}

class OpsRuntimePaths {
  const OpsRuntimePaths({
    required this.available,
    this.error,
    this.items = const [],
  });

  final bool available;
  final String? error;
  final List<OpsRuntimePathItem> items;

  factory OpsRuntimePaths.fromJson(Map<String, dynamic> json) {
    final items = <OpsRuntimePathItem>[];
    final raw = json['items'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(OpsRuntimePathItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return OpsRuntimePaths(
      available: json['available'] != false,
      error: json['error']?.toString(),
      items: items,
    );
  }
}

class OpsRuntimePathItem {
  const OpsRuntimePathItem({required this.label, required this.path});

  final String label;
  final String path;

  factory OpsRuntimePathItem.fromJson(Map<String, dynamic> json) {
    return OpsRuntimePathItem(
      label: '${json['label'] ?? ''}',
      path: '${json['path'] ?? ''}',
    );
  }
}

int _asInt(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? fallback;
}

int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

class OpsCredentialBundle {
  const OpsCredentialBundle({
    required this.siteId,
    required this.certId,
    required this.baseUrl,
    required this.clientPrivateKeyPem,
    required this.clientPublicKeyPem,
    required this.serverPublicKey,
    this.serverFingerprint,
    this.label,
  });

  final String siteId;
  final String certId;
  final String baseUrl;
  final String clientPrivateKeyPem;
  final String clientPublicKeyPem;
  final String serverPublicKey;
  final String? serverFingerprint;
  final String? label;

  Map<String, dynamic> toJson() => {
        'v': 1,
        'siteId': siteId,
        'certId': certId,
        'baseUrl': baseUrl,
        'clientPrivateKeyPem': clientPrivateKeyPem,
        'clientPublicKeyPem': clientPublicKeyPem,
        'serverPublicKey': serverPublicKey,
        'serverFingerprint': serverFingerprint,
        'label': label,
      };

  factory OpsCredentialBundle.fromJson(Map<String, dynamic> json) {
    return OpsCredentialBundle(
      siteId: '${json['siteId'] ?? ''}',
      certId: '${json['certId'] ?? ''}',
      baseUrl: '${json['baseUrl'] ?? ''}',
      clientPrivateKeyPem: '${json['clientPrivateKeyPem'] ?? ''}',
      clientPublicKeyPem: '${json['clientPublicKeyPem'] ?? ''}',
      serverPublicKey: '${json['serverPublicKey'] ?? ''}',
      serverFingerprint: json['serverFingerprint']?.toString(),
      label: json['label']?.toString(),
    );
  }
}
